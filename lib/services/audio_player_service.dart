import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:nsd/nsd.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'youtube_service.dart';
import 'music_service.dart';

/// Connection state enum for UI (renamed to avoid Flutter conflict)
enum ProxyConnectionState {
  searching,
  connected,
  disconnected,
}

/// Singleton wrapper around just_audio for queue + playback control.
class AudioPlayerService {
  AudioPlayerService._internal() {
    _init();
    _startMultiStrategyDiscovery();
  }
  static final AudioPlayerService instance = AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final YoutubeService _youtube = YoutubeService.instance;

  // YOUR TAILSCALE IP - replace if it changes
  static const String TAILSCALE_SERVER_IP = '100.107.148.88';

  // Dynamic proxy URL - updated automatically
  String _proxyBaseUrl = "";

  // Discovery state tracking
  bool _isDiscovering = false;
  String? _cachedIP;
  Timer? _periodicRediscovery;

  // Discovery status stream for UI feedback
  final _discoveryStatusController = StreamController<String>.broadcast();
  Stream<String> get discoveryStatusStream => _discoveryStatusController.stream;

  // Connection state
  final _connectionStateController = StreamController<ProxyConnectionState>.broadcast();
  Stream<ProxyConnectionState> get connectionStateStream => _connectionStateController.stream;

  List<Track> _queue = [];
  int _currentIndex = 0;
  bool _loadingYoutube = false;

  // Public Getters for Provider
  bool get isPlaying => _player.playing;
  List<Track> get queue => List.unmodifiable(_queue);
  bool get isLoadingYoutube => _loadingYoutube;
  bool get isProxyConnected => _proxyBaseUrl.isNotEmpty && _proxyBaseUrl.startsWith('http');
  Track? get currentTrack =>
      _queue.isNotEmpty && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  // Streams for UI
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

    // Load cached IP on startup
    _loadCachedIP();
  }

  /// Load previously successful IP from cache
  Future<void> _loadCachedIP() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedIP = prefs.getString('proxy_ip');
      if (_cachedIP != null) {
        _updateStatus('📋 Loaded cached IP: $_cachedIP');
      }
    } catch (e) {
      print('[Sonix] ⚠️ Could not load cached IP: $e');
    }
  }

  /// Cache successful IP for faster reconnection
  Future<void> _cacheIP(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('proxy_ip', ip);
      _cachedIP = ip;
      print('[Sonix] 💾 Cached proxy IP: $ip');
    } catch (e) {
      print('[Sonix] ⚠️ Could not cache IP: $e');
    }
  }

  /// Update discovery status for UI
  void _updateStatus(String status) {
    print('[Sonix] $status');
    _discoveryStatusController.add(status);
  }

  /// Main discovery orchestrator - tries multiple strategies
  Future<void> _startMultiStrategyDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _connectionStateController.add(ProxyConnectionState.searching);

    _updateStatus('🔍 Starting multi-strategy discovery...');

    // Strategy 0: Try Tailscale IP (works anywhere!)
    _updateStatus('🌐 Trying Tailscale IP: $TAILSCALE_SERVER_IP');
    if (await _testProxyConnection(TAILSCALE_SERVER_IP)) {
      _setProxyUrl(TAILSCALE_SERVER_IP);
      _isDiscovering = false;
      _connectionStateController.add(ProxyConnectionState.connected);
      return;
    }

    // Strategy 1: Try cached IP first (fastest)
    if (_cachedIP != null) {
      _updateStatus('⚡ Trying cached IP: $_cachedIP');
      if (await _testProxyConnection(_cachedIP!)) {
        _setProxyUrl(_cachedIP!);
        _isDiscovering = false;
        _connectionStateController.add(ProxyConnectionState.connected);
        return;
      }
    }

    // Strategy 2: NSD/mDNS discovery (best for WiFi networks)
    _updateStatus('📡 Strategy 2/4: NSD Discovery');
    final nsdFound = await _tryNSDDiscovery();
    if (nsdFound) {
      _isDiscovering = false;
      _connectionStateController.add(ProxyConnectionState.connected);
      return;
    }

    // Strategy 3: Smart IP scanning (works on hotspots)
    _updateStatus('🔎 Strategy 3/4: Smart IP Scanning');
    final scanFound = await _trySmartIPScanning();
    if (scanFound) {
      _isDiscovering = false;
      _connectionStateController.add(ProxyConnectionState.connected);
      return;
    }

    // Strategy 4: Common hotspot IPs (last resort)
    _updateStatus('🎯 Strategy 4/4: Common Hotspot IPs');
    final commonFound = await _tryCommonHotspotIPs();
    if (commonFound) {
      _isDiscovering = false;
      _connectionStateController.add(ProxyConnectionState.connected);
      return;
    }

    // All strategies failed
    _updateStatus('❌ No proxy found. Will retry automatically.');
    _connectionStateController.add(ProxyConnectionState.disconnected);
    _isDiscovering = false;

    // Schedule periodic rediscovery
    _scheduleRediscovery();
  }

  /// Strategy 1: NSD Discovery (15 second timeout)
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
            final ip = host;

            _setProxyUrl(ip, port: port);
            _updateStatus('✅ NSD found SonixProxy at $ip:$port');

            stopDiscovery(discovery);
          }
        }
      });

      await Future.delayed(const Duration(seconds: 15));

      if (!found) {
        stopDiscovery(discovery);
        _updateStatus('⏱️ NSD timed out (15s)');
      }

      return found;
    } catch (e) {
      _updateStatus('⚠️ NSD error: $e');
      return false;
    }
  }

  /// Strategy 2: Smart IP Scanning based on device's own IP
  Future<bool> _trySmartIPScanning() async {
    try {
      final ownIP = await _getDeviceIP();
      if (ownIP == null) {
        _updateStatus('⚠️ Could not determine device IP');
        return false;
      }

      final parts = ownIP.split('.');
      if (parts.length != 4) return false;

      final networkPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';

      final ipsToTest = <String>{};

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

      _updateStatus('🔍 Testing ${ipsToTest.length} IPs...');

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
            _updateStatus('✅ Found proxy at $foundIP');
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      _updateStatus('⚠️ IP scanning error: $e');
      return false;
    }
  }

  /// Strategy 3: Common Hotspot IPs (fallback)
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

    _updateStatus('🔍 Testing ${commonIPs.length} common hotspot IPs...');

    for (final ip in commonIPs) {
      if (await _testProxyConnection(ip)) {
        _setProxyUrl(ip);
        _updateStatus('✅ Found proxy at $ip (common IP)');
        return true;
      }
    }

    _updateStatus('❌ No common hotspot IPs worked');
    return false;
  }

  /// Test if a specific IP:port combination has our proxy server
  Future<bool> _testProxyConnection(String ip, {int port = 5000}) async {
    try {
      final client = http.Client();
      try {
        final testUrl = 'http://$ip:$port/';

        final response = await client.get(
          Uri.parse(testUrl),
        ).timeout(
          const Duration(milliseconds: 3000), // Changed from 800 to 3000
        );

        return true;
      } finally {
        client.close();
      }
    } catch (e) {
      return false;
    }
  }

  /// Set the proxy URL and cache it
  void _setProxyUrl(String ip, {int port = 5000}) {
    _proxyBaseUrl = "http://$ip:$port/play?id=";
    MusicService.instance.updateBaseUrl("http://$ip:$port");
    _cacheIP(ip);
    _updateStatus('🔗 Proxy URL set: $_proxyBaseUrl');
  }

  /// Get device's current IP address
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
      _updateStatus('⚠️ Error getting device IP: $e');
    }
    return null;
  }

  /// Schedule periodic rediscovery if not connected
  void _scheduleRediscovery() {
    _periodicRediscovery?.cancel();
    _periodicRediscovery = Timer.periodic(
      const Duration(seconds: 30),
          (_) {
        if (!isProxyConnected) {
          _updateStatus('🔄 Auto-retrying discovery...');
          _startMultiStrategyDiscovery();
        } else {
          _periodicRediscovery?.cancel();
        }
      },
    );
  }

  /// Manual retry - can be called from UI
  Future<void> retryDiscovery() async {
    _updateStatus('🔄 Manual rediscovery triggered...');
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

    // If not connected, try Tailscale first, then local network
    if (!isProxyConnected) {
      _updateStatus('⏳ Looking for server...');

      // Try Tailscale first (works anywhere with internet)
      if (await _testProxyConnection(TAILSCALE_SERVER_IP)) {
        _setProxyUrl(TAILSCALE_SERVER_IP);
        _updateStatus('✅ Connected via Tailscale');
      }
      // Try local network
      else if (!isProxyConnected) {
        if (await _quickNetworkScan()) {
          // _setProxyUrl was called inside _quickNetworkScan
        }
      }

      if (!isProxyConnected) {
        _updateStatus('🎵 No server found, using preview');
        if (t.previewUrl.isNotEmpty) {
          try {
            await _player.setUrl(t.previewUrl);
            if (autoPlay) _player.play();
          } catch (e) {
            print('[Sonix] ❌ Preview playback failed: $e');
          }
        }
        return;
      }
    }

    try {
      _loadingYoutube = true;
      _loadingController.add(true);
      _trackChangedController.add(t);

      _updateStatus('🔎 Searching YouTube for: ${t.title}');

      final videoId = await _youtube.getVideoId(t.title, t.artistName).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _updateStatus('⏱️ YouTube search timed out');
          return null;
        },
      );

      if (videoId != null && videoId.isNotEmpty) {
        final fullUrl = "$_proxyBaseUrl${videoId.trim()}";
        _updateStatus('🎵 Loading full track...');

        // Try playback with retries
        bool played = false;
        for (int attempt = 0; attempt < 3; attempt++) {
          try {
            // Use ConcatenatingAudioSource for better timeout handling
            await _player.setAudioSource(
              AudioSource.uri(
                Uri.parse(fullUrl),
                tag: 'full_track',
              ),
            );

            if (autoPlay) {
              await _player.play();
            }

            _updateStatus('✅ Playing full track');
            played = true;
            break;
          } catch (e) {
            _updateStatus('⚠️ Playback attempt ${attempt + 1} failed: $e');
            if (attempt < 2) {
              _updateStatus('🔄 Retrying...');
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        }

        if (!played) {
          throw Exception('All playback attempts failed');
        }
      } else {
        _updateStatus('⚠️ YouTube search failed, using preview');
        if (t.previewUrl.isNotEmpty) {
          await _player.setUrl(t.previewUrl);
          if (autoPlay) _player.play();
        }
      }
    } catch (e) {
      _updateStatus('⚠️ Full track failed, using preview');
      print('[Sonix] ❌ Playback error: $e');
      _cachedIP = null;
      _proxyBaseUrl = "";

      if (t.previewUrl.isNotEmpty) {
        try {
          await _player.setUrl(t.previewUrl);
          if (autoPlay) _player.play();
        } catch (previewError) {
          print('[Sonix] ❌ Preview also failed: $previewError');
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
      _updateStatus('🔎 background search starting for: ${t.title}');

      final videoId = await _youtube.getVideoId(t.title, t.artistName).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _updateStatus('⏱️ YouTube search timed out.');
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
      _updateStatus('⚠️ Swap background error: $e');
    } finally {
      _loadingYoutube = false;
      _loadingController.add(false);
    }
  }

  // Quick network scan that updates the proxy URL directly
  Future<bool> _quickNetworkScan() async {
    final ownIP = await _getDeviceIP();
    if (ownIP == null) return false;

    final parts = ownIP.split('.');
    if (parts.length != 4) return false;

    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';

    // Test gateway first (most common)
    if (await _testProxyConnection('$prefix.1')) {
      _setProxyUrl('$prefix.1');
      return true;
    }

    // Test a few common alternatives
    for (final testIP in ['$prefix.2', '$prefix.100', '$prefix.101']) {
      if (await _testProxyConnection(testIP)) {
        _setProxyUrl(testIP);
        return true;
      }
    }

    return false;
  }

  // --- CONTROLS ---

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