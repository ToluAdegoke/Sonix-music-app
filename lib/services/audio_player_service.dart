import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:nsd/nsd.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'youtube_service.dart';
import 'music_service.dart';

enum ProxyConnectionState {
  searching,
  connected,
  disconnected,
}

class AudioPlayerService {
  AudioPlayerService._internal() {
    _init();
    _startMultiStrategyDiscovery();
  }
  static final AudioPlayerService instance = AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final YoutubeService _youtube = YoutubeService.instance;

  // Static fallback IP for remote connection
  static const String TAILSCALE_SERVER_IP = '100.107.148.88';

  String _proxyBaseUrl = "";
  bool _isDiscovering = false;
  String? _cachedIP;
  Timer? _periodicRediscovery;

  final _discoveryStatusController = StreamController<String>.broadcast();
  Stream<String> get discoveryStatusStream => _discoveryStatusController.stream;

  final _connectionStateController = StreamController<ProxyConnectionState>.broadcast();
  Stream<ProxyConnectionState> get connectionStateStream => _connectionStateController.stream;

  List<Track> _queue = [];
  int _currentIndex = 0;
  bool _loadingYoutube = false;

  bool get isPlaying => _player.playing;
  List<Track> get queue => List.unmodifiable(_queue);
  bool get isLoadingYoutube => _loadingYoutube;
  bool get isProxyConnected => _proxyBaseUrl.isNotEmpty && _proxyBaseUrl.startsWith('http');
  Track? get currentTrack =>
      _queue.isNotEmpty && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get playingStream => _player.playingStream;

  final _trackChangedController = StreamController<Track?>.broadcast();
  Stream<Track?> get currentTrackStream => _trackChangedController.stream;

  final _loadingController = StreamController<bool>.broadcast();
  Stream<bool> get loadingStream => _loadingController.stream;

  void _init() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
    });
    _loadCachedIP();
  }

  Future<void> _loadCachedIP() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedIP = prefs.getString('proxy_ip');
      if (_cachedIP != null) {
        _updateStatus('Loaded cached IP from storage: $_cachedIP');
      }
    } catch (e) {
      print('[Sonix] Error loading cached IP: $e');
    }
  }

  Future<void> _cacheIP(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('proxy_ip', ip);
      _cachedIP = ip;
      print('[Sonix] Saved active proxy IP: $ip');
    } catch (e) {
      print('[Sonix] Cache write failed: $e');
    }
  }

  void _updateStatus(String status) {
    print('[Sonix] $status');
    _discoveryStatusController.add(status);
  }

  // Sequentially run network discovery methods
  Future<void> _startMultiStrategyDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _connectionStateController.add(ProxyConnectionState.searching);

    _updateStatus('Initializing connection sequence...');

    // 1. Try hardcoded Tailscale address
    _updateStatus('Testing Tailscale entry: $TAILSCALE_SERVER_IP');
    if (await _testProxyConnection(TAILSCALE_SERVER_IP)) {
      _setProxyUrl(TAILSCALE_SERVER_IP);
      _isDiscovering = false;
      _connectionStateController.add(ProxyConnectionState.connected);
      return;
    }

    // 2. Fall back to last known active IP
    if (_cachedIP != null) {
      _updateStatus('Testing last known local target: $_cachedIP');
      if (await _testProxyConnection(_cachedIP!)) {
        _setProxyUrl(_cachedIP!);
        _isDiscovering = false;
        _connectionStateController.add(ProxyConnectionState.connected);
        return;
      }
    }

    // 3. Look for service broadcast on the network
    _updateStatus('Scanning via mDNS/NSD...');
    final nsdFound = await _tryNSDDiscovery();
    if (nsdFound) {
      _isDiscovering = false;
      _connectionStateController.add(ProxyConnectionState.connected);
      return;
    }

    // 4. Fall back to local network sweep
    _updateStatus('Scanning local subnet ranges...');
    final scanFound = await _trySmartIPScanning();
    if (scanFound) {
      _isDiscovering = false;
      _connectionStateController.add(ProxyConnectionState.connected);
      return;
    }

    // 5. Check typical gateway setups
    _updateStatus('Checking default access points...');
    final commonFound = await _tryCommonHotspotIPs();
    if (commonFound) {
      _isDiscovering = false;
      _connectionStateController.add(ProxyConnectionState.connected);
      return;
    }

    _updateStatus('No response from local backend. Retries scheduled.');
    _connectionStateController.add(ProxyConnectionState.disconnected);
    _isDiscovering = false;

    _scheduleRediscovery();
  }

  Future<bool> _tryNSDDiscovery() async {
    try {
      final discovery = await startDiscovery('_http._tcp.local.');
      bool found = false;

      discovery.addListener(() {
        for (var service in discovery.services) {
          if (service.name == "SonixProxy" && !found) {
            found = true;
            final host = service.addresses!.first.address;
            final port = service.port ?? 5000;

            _setProxyUrl(host, port: port);
            _updateStatus('Found proxy target via NSD at $host:$port');
            stopDiscovery(discovery);
          }
        }
      });

      await Future.delayed(const Duration(seconds: 15));

      if (!found) {
        stopDiscovery(discovery);
        _updateStatus('NSD scan window closed without response.');
      }

      return found;
    } catch (e) {
      _updateStatus('NSD driver exception: $e');
      return false;
    }
  }

  Future<bool> _trySmartIPScanning() async {
    try {
      final ownIP = await _getDeviceIP();
      if (ownIP == null) {
        _updateStatus('Interface lookup failed; skipping subnet sweep.');
        return false;
      }

      final parts = ownIP.split('.');
      if (parts.length != 4) return false;

      final networkPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      final ipsToTest = <String>{};

      // Map likely server hosts on the local network block
      ipsToTest.addAll([
        '$networkPrefix.1',
        '$networkPrefix.2',
        '$networkPrefix.100',
        '$networkPrefix.101',
        '$networkPrefix.10',
        '$networkPrefix.20',
        '$networkPrefix.50',
      ]);

      for (int i = 100; i <= 150; i += 5) {
        ipsToTest.add('$networkPrefix.$i');
      }

      for (int i = 2; i <= 20; i++) {
        ipsToTest.add('$networkPrefix.$i');
      }

      final currentLastOctet = int.tryParse(parts[3]) ?? 0;
      for (int i = -10; i <= 10; i++) {
        final neighborOctet = currentLastOctet + i;
        if (neighborOctet > 0 && neighborOctet < 255 && neighborOctet != currentLastOctet) {
          ipsToTest.add('$networkPrefix.$neighborOctet');
        }
      }

      _updateStatus('Probing ${ipsToTest.length} potential local endpoints...');

      final ipList = ipsToTest.toList();
      for (int i = 0; i < ipList.length; i += 10) {
        final batch = ipList.skip(i).take(10);
        final results = await Future.wait(
          batch.map((ip) => _testProxyConnection(ip)),
        );

        for (int j = 0; j < batch.length; j++) {
          if (results[j]) {
            final foundIP = batch.elementAt(j);
            _setProxyUrl(foundIP);
            _updateStatus('Endpoint match found: $foundIP');
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      _updateStatus('Subnet probe threw exception: $e');
      return false;
    }
  }

  Future<bool> _tryCommonHotspotIPs() async {
    final commonIPs = <String>{};

    try {
      final ownIP = await _getDeviceIP();
      if (ownIP != null) {
        final parts = ownIP.split('.');
        if (parts.length == 4) {
          commonIPs.add('${parts[0]}.${parts[1]}.${parts[2]}.1');
          commonIPs.add('${parts[0]}.${parts[1]}.${parts[2]}.2');
        }
      }
    } catch (_) {}

    commonIPs.addAll([
      '192.168.43.1',
      '192.168.137.1',
      '172.20.10.1',
      '192.168.42.1',
      '10.0.0.1',
      '192.168.0.1',
      '192.168.1.1',
      '192.168.43.43',
      '192.168.43.10',
    ]);

    _updateStatus('Pinging common tethering interfaces...');

    for (final ip in commonIPs) {
      if (await _testProxyConnection(ip)) {
        _setProxyUrl(ip);
        _updateStatus('Connected via interface: $ip');
        return true;
      }
    }

    _updateStatus('Default interface check completed without links.');
    return false;
  }

  Future<bool> _testProxyConnection(String ip, {int port = 5000}) async {
    try {
      final client = http.Client();
      try {
        final testUrl = 'http://$ip:$port/';
        await client.get(Uri.parse(testUrl)).timeout(
          const Duration(milliseconds: 3000), // Increased to stabilize mobile handshakes
        );
        return true;
      } finally {
        client.close();
      }
    } catch (e) {
      return false;
    }
  }

  void _setProxyUrl(String ip, {int port = 5000}) {
    _proxyBaseUrl = "http://$ip:$port/play?id=";
    MusicService.instance.updateBaseUrl("http://$ip:$port");
    _cacheIP(ip);
    _updateStatus('Active API target configuration updated.');
  }

  Future<String?> _getDeviceIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback &&
              !addr.address.startsWith('127.') &&
              !addr.address.startsWith('169.254.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      _updateStatus('Failed to capture active hardware address: $e');
    }
    return null;
  }

  void _scheduleRediscovery() {
    _periodicRediscovery?.cancel();
    _periodicRediscovery = Timer.periodic(
      const Duration(seconds: 30),
          (_) {
        if (!isProxyConnected) {
          _updateStatus('Retrying connection routine...');
          _startMultiStrategyDiscovery();
        } else {
          _periodicRediscovery?.cancel();
        }
      },
    );
  }

  Future<void> retryDiscovery() async {
    _updateStatus('Manual connection sweep called.');
    await _startMultiStrategyDiscovery();
  }

  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _queue = List.of(tracks);
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    await _loadCurrent(autoPlay: true);
  }

  Future<void> _loadCurrent({bool autoPlay = true}) async {
    final t = currentTrack;
    if (t == null) return;

    if (!isProxyConnected) {
      _updateStatus('No active server endpoint. Dropping to fallback lookups...');

      if (await _testProxyConnection(TAILSCALE_SERVER_IP)) {
        _setProxyUrl(TAILSCALE_SERVER_IP);
        _updateStatus('Established link over remote overlay network.');
      } else if (!isProxyConnected) {
        await _quickNetworkScan();
      }

      if (!isProxyConnected) {
        _updateStatus('Proxy unavailable; attempting 30s audio sample preview...');
        if (t.previewUrl.isNotEmpty) {
          try {
            await _player.setUrl(t.previewUrl);
            if (autoPlay) _player.play();
          } catch (e) {
            print('[Sonix] Fallback track stream failed: $e');
          }
        }
        return;
      }
    }

    try {
      _loadingYoutube = true;
      _loadingController.add(true);
      _trackChangedController.add(t);

      _updateStatus('Resolving streaming resource for: ${t.title}');

      final videoId = await _youtube.getVideoId(t.title, t.artistName).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _updateStatus('Resource engine lookup timed out.');
          return null;
        },
      );

      if (videoId != null && videoId.isNotEmpty) {
        final fullUrl = "$_proxyBaseUrl${videoId.trim()}";
        _updateStatus('Buffering full-length stream...');

        bool played = false;
        for (int attempt = 0; attempt < 3; attempt++) {
          try {
            await _player.setAudioSource(
              AudioSource.uri(
                Uri.parse(fullUrl),
                tag: 'full_track',
              ),
            );

            if (autoPlay) {
              await _player.play();
            }

            _updateStatus('Full track streaming initialized.');
            played = true;
            break;
          } catch (e) {
            _updateStatus('Stream pipeline write failed (attempt ${attempt + 1}): $e');
            if (attempt < 2) {
              _updateStatus('Re-initializing pipeline...');
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        }

        if (!played) {
          throw Exception('Pipeline failure across all retry handles.');
        }
      } else {
        _updateStatus('Resource engine missing index; falling back to sample preview.');
        if (t.previewUrl.isNotEmpty) {
          await _player.setUrl(t.previewUrl);
          if (autoPlay) _player.play();
        }
      }
    } catch (e) {
      _updateStatus('Stream failed; dropping back to short sample.');
      print('[Sonix] Pipeline error context: $e');
      _cachedIP = null;
      _proxyBaseUrl = "";

      if (t.previewUrl.isNotEmpty) {
        try {
          await _player.setUrl(t.previewUrl);
          if (autoPlay) _player.play();
        } catch (previewError) {
          print('[Sonix] Secondary pipeline failure: $previewError');
        }
      }
    } finally {
      _loadingYoutube = false;
      _loadingController.add(false);
    }
  }

  Future<void> _performFullTrackSearch(Track t, bool autoPlay) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      _updateStatus('Background processing query for: ${t.title}');

      final videoId = await _youtube.getVideoId(t.title, t.artistName).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _updateStatus('Background resolver query timed out.');
          return null;
        },
      );

      if (videoId != null && videoId.isNotEmpty && currentTrack?.id == t.id) {
        final cleanProxyUrl = "$_proxyBaseUrl${videoId.trim()}";
        final currentPos = _player.position;

        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(cleanProxyUrl)),
          initialPosition: currentPos.inSeconds > 27 ? Duration.zero : currentPos,
        );

        if (autoPlay) _player.play();
      }
    } catch (e) {
      _updateStatus('Background player hot-swap exception: $e');
    } finally {
      _loadingYoutube = false;
      _loadingController.add(false);
    }
  }

  Future<bool> _quickNetworkScan() async {
    final ownIP = await _getDeviceIP();
    if (ownIP == null) return false;

    final parts = ownIP.split('.');
    if (parts.length != 4) return false;

    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';

    if (await _testProxyConnection('$prefix.1')) {
      _setProxyUrl('$prefix.1');
      return true;
    }

    for (final testIP in ['$prefix.2', '$prefix.100', '$prefix.101']) {
      if (await _testProxyConnection(testIP)) {
        _setProxyUrl(testIP);
        return true;
      }
    }

    return false;
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> togglePlay() async {
    _player.playing ? await _player.pause() : await _player.play();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _loadCurrent();
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await _loadCurrent();
    }
  }

  Future<void> dispose() async {
    _periodicRediscovery?.cancel();
    await _player.dispose();
    await _trackChangedController.close();
    await _loadingController.close();
    await _discoveryStatusController.close();
    await _connectionStateController.close();
  }
}