import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';

import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _artController;
  late Animation<double> _artScale;
  String? _lastTrackId;

  StreamSubscription<ProxyConnectionState>? _connectionSubscription;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _artController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _artScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _artController, curve: Curves.easeOutBack),
    );
    _artController.forward();

    // Silent connection listener - no snackbars, no status bar
    _connectionSubscription = AudioPlayerService.instance.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isConnected = state == ProxyConnectionState.connected;
        });
      }
    });
  }

  @override
  void dispose() {
    _artController.dispose();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _animateArtChange() {
    _artController.reset();
    _artController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final track = player.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: const Center(
          child: Text('No track playing',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    if (_lastTrackId != track.id.toString()) {
      _lastTrackId = track.id.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateArtChange());
    }

    final liked = library.isLiked(track);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: track.albumCover,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) =>
                Container(color: AppColors.background),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, track),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Expanded(
                          flex: 5,
                          child: Center(
                            child: ScaleTransition(
                              scale: _artScale,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 40,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: CachedNetworkImage(
                                      imageUrl: track.albumCover,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => Container(
                                        color: AppColors.surface,
                                        child: const Icon(Icons.music_note,
                                            size: 80,
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    track.artistName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => library.toggleLike(track),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  liked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  key: ValueKey(liked),
                                  color: liked
                                      ? AppColors.accent
                                      : Colors.white.withOpacity(0.7),
                                  size: 28,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _SeekBar(),
                        const SizedBox(height: 16),
                        _buildControls(player),
                        const SizedBox(height: 20),
                        _buildExtraControls(),
                        const SizedBox(height: 12),
                        // Only show a subtle indicator if connected
                        if (_isConnected)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade400,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.shade400.withOpacity(0.6),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Full track',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            '30-second preview • Powered by Deezer',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, track) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'PLAYING FROM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.albumTitle ?? 'Sonix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_horiz,
                color: Colors.white.withOpacity(0.8), size: 28),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildControls(PlayerProvider player) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: Icons.shuffle,
          color: Colors.white.withOpacity(0.6),
          size: 22,
          onTap: () {},
        ),
        _ControlButton(
          icon: Icons.skip_previous_rounded,
          color: Colors.white,
          size: 46,
          onTap: player.previous,
        ),
        StreamBuilder<bool>(
          stream: context.read<PlayerProvider>().service.loadingStream,
          builder: (ctx, snap) {
            final loading = snap.data ?? false;
            return GestureDetector(
              onTap: player.togglePlay,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: loading
                    ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2.5,
                  ),
                )
                    : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey(player.isPlaying),
                    color: Colors.black,
                    size: 42,
                  ),
                ),
              ),
            );
          },
        ),
        _ControlButton(
          icon: Icons.skip_next_rounded,
          color: Colors.white,
          size: 46,
          onTap: player.next,
        ),
        _ControlButton(
          icon: Icons.repeat,
          color: Colors.white.withOpacity(0.6),
          size: 22,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildExtraControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(Icons.devices, color: Colors.white.withOpacity(0.6), size: 20),
        Icon(Icons.share_outlined,
            color: Colors.white.withOpacity(0.6), size: 20),
        Icon(Icons.queue_music_outlined,
            color: Colors.white.withOpacity(0.6), size: 20),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: size),
    );
  }
}

class _SeekBar extends StatelessWidget {
  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<PlayerProvider>().service;
    return StreamBuilder<Duration>(
      stream: svc.positionStream,
      builder: (ctx, posSnap) {
        final position = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: svc.durationStream,
          builder: (ctx2, durSnap) {
            final duration =
                durSnap.data ?? const Duration(seconds: 30);
            final maxMs = duration.inMilliseconds
                .toDouble()
                .clamp(1.0, double.infinity);
            final valMs =
            position.inMilliseconds.toDouble().clamp(0.0, maxMs);
            return Column(
              children: [
                Slider(
                  min: 0,
                  max: maxMs,
                  value: valMs,
                  onChanged: (v) =>
                      svc.seek(Duration(milliseconds: v.toInt())),
                ),
                Row(
                  children: [
                    Text(_fmt(position)),
                    const Spacer(),
                    Text(_fmt(duration)),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}