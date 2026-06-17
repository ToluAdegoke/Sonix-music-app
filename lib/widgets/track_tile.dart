import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final List<Track>? contextQueue;
  final int? indexInQueue;
  final bool showAlbumArt;

  const TrackTile({
    super.key,
    required this.track,
    this.contextQueue,
    this.indexInQueue,
    this.showAlbumArt = true,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final isCurrent = player.currentTrack?.id == track.id;
    final liked = library.isLiked(track);

    return InkWell(
      onTap: () {
        final queue = contextQueue ?? [track];
        final idx = indexInQueue ?? 0;
        player.playTracks(queue, startIndex: idx);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (showAlbumArt)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: track.albumCoverSmall,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    width: 52,
                    height: 52,
                    color: AppColors.surface,
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: 52,
                    height: 52,
                    color: AppColors.surface,
                    child: const Icon(Icons.music_note,
                        color: AppColors.textSecondary),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isCurrent
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Like button
            IconButton(
              icon: Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                color: liked ? AppColors.accent : AppColors.textSecondary,
                size: 22,
              ),
              onPressed: () => library.toggleLike(track),
            ),
            // More button
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.textSecondary,
                size: 22,
              ),
              onPressed: () => _showMoreMenu(context, track, library, liked),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu(
      BuildContext context,
      Track track,
      LibraryProvider library,
      bool liked,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final playlists = library.playlists;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Track info
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: track.albumCoverSmall,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 48,
                            height: 48,
                            color: AppColors.background,
                            child: const Icon(Icons.music_note,
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.divider, height: 1),
                // Like/Unlike
                ListTile(
                  leading: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? AppColors.accent : AppColors.textPrimary,
                  ),
                  title: Text(
                    liked ? 'Remove from liked' : 'Add to liked songs',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  onTap: () {
                    library.toggleLike(track);
                    Navigator.pop(ctx);
                  },
                ),
                // Add to playlist
                ListTile(
                  leading: const Icon(
                    Icons.playlist_add_rounded,
                    color: AppColors.textPrimary,
                  ),
                  title: const Text(
                    'Add to playlist',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPlaylistPicker(context, track, library);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlaylistPicker(
      BuildContext context,
      Track track,
      LibraryProvider library,
      ) {
    final playlists = library.playlists;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Add to playlist',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No playlists yet.\nGo to Library to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...playlists.keys.map(
                      (name) => ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${playlists[name]!.length} tracks',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      library.addTrackToPlaylist(name, track);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added to $name'),
                          backgroundColor: AppColors.surface,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}