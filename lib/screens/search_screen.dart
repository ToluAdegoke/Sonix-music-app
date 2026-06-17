import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/music_service.dart'; // Make sure this path is correct
import '../services/audio_player_service.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../services/deezer_api.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_card.dart';
import '../widgets/section_header.dart';
import '../widgets/track_tile.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // OLD: final MusicService _musicService = MusicService();
// NEW:
  final MusicService _musicService = MusicService.instance;
  final DeezerApi _api = DeezerApi();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  List<Track> _tracks = [];
  List<Artist> _artists = [];
  List<Album> _albums = [];
  bool _loading = false;
  bool _focused = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    _lastQuery = query;
    if (query.isEmpty) {
      setState(() {
        _tracks = [];
        _artists = [];
        _albums = [];
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.searchTracks(query, limit: 25),
        _api.searchArtists(query, limit: 10),
        _api.searchAlbums(query, limit: 10),
      ]);
      if (!mounted || query != _lastQuery) return;
      setState(() {
        _tracks = results[0] as List<Track>;
        _artists = results[1] as List<Artist>;
        _albums = results[2] as List<Album>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _tracks = [];
      _artists = [];
      _albums = [];
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: const Text(
                'Search',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onChanged,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Songs, artists, albums…',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? GestureDetector(
                      onTap: _clearSearch,
                      child: const Icon(
                        Icons.cancel,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            // Results
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else
              Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_controller.text.isEmpty) {
      return _buildEmptyState();
    }
    if (_tracks.isEmpty && _artists.isEmpty && _albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No results for "${_controller.text}"',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (_artists.isNotEmpty) ...[
          const SectionHeader(title: 'Artists'),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              cacheExtent: 500,
              itemCount: _artists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                final a = _artists[i];
                return CoverCard(
                  imageUrl: a.picture,
                  title: a.name,
                  size: 130,
                  circular: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArtistDetailScreen(artist: a),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (_albums.isNotEmpty) ...[
          const SectionHeader(title: 'Albums'),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              cacheExtent: 500,
              itemCount: _albums.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                final a = _albums[i];
                return CoverCard(
                  imageUrl: a.cover,
                  title: a.title,
                  subtitle: a.artistName,
                  size: 150,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlbumDetailScreen(album: a),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (_tracks.isNotEmpty) ...[
          const SectionHeader(title: 'Songs'),
          ..._tracks.asMap().entries.map(
                (e) {
              final track = e.value;
              return GestureDetector(
                onTap: () {
                  // This is the magic part: search for "Artist - Title" on your proxy
                  final query = "${track.artistName} - ${track.title}";
                  // OLD: _musicService.playSong(query);
                  // NEW:
                  AudioPlayerService.instance.playQueue([track]);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Loading ${track.title} via Proxy..."),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: TrackTile(
                  track: track,
                  contextQueue: _tracks,
                  indexInQueue: e.key,
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    final categories = [
      {'label': 'Afrobeats', 'color': const Color(0xFF1DB954)},
      {'label': 'Hip-Hop', 'color': const Color(0xFF9B59B6)},
      {'label': 'Pop', 'color': const Color(0xFFE74C3C)},
      {'label': 'R&B', 'color': const Color(0xFF2980B9)},
      {'label': 'Jazz', 'color': const Color(0xFFE67E22)},
      {'label': 'Classical', 'color': const Color(0xFF1ABC9C)},
      {'label': 'Rock', 'color': const Color(0xFF34495E)},
      {'label': 'Electronic', 'color': const Color(0xFFF39C12)},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        const Text(
          'Browse categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemCount: categories.length,
          itemBuilder: (ctx, i) {
            final cat = categories[i];
            return GestureDetector(
              onTap: () {
                _controller.text = cat['label'] as String;
                _search(cat['label'] as String);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: cat['color'] as Color,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Text(
                  cat['label'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}