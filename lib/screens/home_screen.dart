import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../services/deezer_api.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_card.dart';
import '../widgets/section_header.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'playlist_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DeezerApi _api = DeezerApi();

  List<Track> _topTracks = [];
  List<Playlist> _playlists = [];
  List<Album> _albums = [];
  List<Artist> _artists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getTopCharts(limit: 15),
        _api.getEditorialPlaylists(limit: 12),
        _api.getTopAlbums(limit: 12),
        _api.getTopArtists(limit: 12),
      ]);
      if (!mounted) return;

      final tracks = results[0] as List<Track>;
      final playlists = results[1] as List<Playlist>;
      final albums = results[2] as List<Album>;
      final artists = results[3] as List<Artist>;

      // Pre-cache all images
      for (final p in playlists) {
        precacheImage(CachedNetworkImageProvider(p.cover), context);
      }
      for (final t in tracks) {
        precacheImage(CachedNetworkImageProvider(t.albumCover), context);
      }
      for (final a in albums) {
        precacheImage(CachedNetworkImageProvider(a.cover), context);
      }
      for (final ar in artists) {
        precacheImage(CachedNetworkImageProvider(ar.picture), context);
      }

      setState(() {
        _topTracks = tracks;
        _playlists = playlists;
        _albums = albums;
        _artists = artists;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: _loading
              ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
              : _error != null
              ? _buildError()
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildError() => ListView(
    children: [
      const SizedBox(height: 200),
      const Icon(Icons.cloud_off, size: 56, color: AppColors.textSecondary),
      const SizedBox(height: 16),
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Failed to load content.\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Retry'),
        ),
      ),
    ],
  );

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      cacheExtent: 800,
      physics: const BouncingScrollPhysics(),
      children: [
        _buildHeader(),
        if (_playlists.isNotEmpty) ...[
          const SectionHeader(title: 'Featured playlists'),
          _buildPlaylistRail(),
        ],
        if (_topTracks.isNotEmpty) ...[
          const SectionHeader(title: 'Trending now', subtitle: 'Top charts'),
          _buildTopTracksRail(),
        ],
        if (_albums.isNotEmpty) ...[
          const SectionHeader(title: 'Popular albums'),
          _buildAlbumsRail(),
        ],
        if (_artists.isNotEmpty) ...[
          const SectionHeader(title: 'Popular artists'),
          _buildArtistsRail(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.graphic_eq, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'Sonix',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          const Text(
            'Good vibes',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistRail() {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        cacheExtent: 500,
        addRepaintBoundaries: true,
        itemCount: _playlists.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final p = _playlists[i];
          return CoverCard(
            imageUrl: p.cover,
            title: p.title,
            subtitle: p.numTracks != null ? '${p.numTracks} tracks' : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaylistDetailScreen(playlist: p),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopTracksRail() {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        cacheExtent: 500,
        addRepaintBoundaries: true,
        itemCount: _topTracks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final t = _topTracks[i];
          return CoverCard(
            imageUrl: t.albumCover,
            title: t.title,
            subtitle: t.artistName,
            onTap: () {
              context
                  .read<PlayerProvider>()
                  .playTracks(_topTracks, startIndex: i);
            },
          );
        },
      ),
    );
  }

  Widget _buildAlbumsRail() {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        cacheExtent: 500,
        addRepaintBoundaries: true,
        itemCount: _albums.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final a = _albums[i];
          return CoverCard(
            imageUrl: a.cover,
            title: a.title,
            subtitle: a.artistName,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: a)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistsRail() {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        cacheExtent: 500,
        addRepaintBoundaries: true,
        itemCount: _artists.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final a = _artists[i];
          return CoverCard(
            imageUrl: a.picture,
            title: a.name,
            circular: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: a)),
            ),
          );
        },
      ),
    );
  }
}