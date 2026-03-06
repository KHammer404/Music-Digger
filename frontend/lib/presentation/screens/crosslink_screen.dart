import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/network/api_client.dart';
import '../blocs/crosslink/crosslink_bloc.dart';
import '../widgets/source_badge.dart';

class CrosslinkScreen extends StatelessWidget {
  final String? initialUrl;
  const CrosslinkScreen({super.key, this.initialUrl});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = CrosslinkBloc(getIt<ApiClient>());
        if (initialUrl != null && initialUrl!.isNotEmpty) {
          bloc.add(CrosslinkSubmitted(initialUrl!));
        }
        return bloc;
      },
      child: const _CrosslinkView(),
    );
  }
}

class _CrosslinkView extends StatefulWidget {
  const _CrosslinkView();

  @override
  State<_CrosslinkView> createState() => _CrosslinkViewState();
}

class _CrosslinkViewState extends State<_CrosslinkView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _controller.text.trim();
    if (url.isNotEmpty) {
      context.read<CrosslinkBloc>().add(CrosslinkSubmitted(url));
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _controller.text = data.text!;
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cross-Platform Link'),
      ),
      body: Column(
        children: [
          // URL input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Paste a music URL...',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste),
                        onPressed: _paste,
                        tooltip: 'Paste from clipboard',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: BlocBuilder<CrosslinkBloc, CrosslinkState>(
              builder: (context, state) {
                return switch (state.status) {
                  CrosslinkStatus.initial => const _InitialHint(),
                  CrosslinkStatus.loading => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  CrosslinkStatus.error => _ErrorContent(
                      message: state.errorMessage ?? 'Unknown error',
                    ),
                  CrosslinkStatus.loaded => _ResultContent(state: state),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialHint extends StatelessWidget {
  const _InitialHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Paste any music link',
            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          Text(
            'YouTube, Spotify, NicoNico, SoundCloud, Bandcamp',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final String message;
  const _ErrorContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  final CrosslinkState state;
  const _ResultContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final original = state.original;
    final isTrack = state.type == 'track';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Original source card
        if (original != null) ...[
          Card(
            color: const Color(0xFF1A1A2E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Thumbnail
                  if (original['thumbnail_url'] != null || original['image_url'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        (original['thumbnail_url'] ?? original['image_url']) as String,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey[800],
                          child: Icon(
                            isTrack ? Icons.music_note : Icons.person,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isTrack ? Icons.music_note : Icons.person,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTrack
                              ? (original['title'] as String? ?? 'Unknown')
                              : (original['name'] as String? ?? 'Unknown'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isTrack && original['artist'] != null)
                          Text(
                            original['artist'] as String,
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SourceBadge(
                              platform: original['platform'] as String? ?? '',
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Original',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Match count
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Found on ${state.matches.length} other platform${state.matches.length == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),

        // Matches
        if (state.matches.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No matches found on other platforms',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          )
        else
          ...state.matches.map((match) => _MatchTile(match: match, isTrack: isTrack)),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _MatchTile extends StatelessWidget {
  final CrosslinkMatch match;
  final bool isTrack;
  const _MatchTile({required this.match, required this.isTrack});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SourceBadge(platform: match.platform, size: 32),
        title: Text(
          isTrack
              ? (match.title ?? SourceBadge.displayName(match.platform))
              : (match.name ?? SourceBadge.displayName(match.platform)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isTrack
              ? (match.artist ?? SourceBadge.displayName(match.platform))
              : SourceBadge.displayName(match.platform),
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: match.isPlayable
            ? const Icon(Icons.play_circle_outline, color: Color(0xFF6C5CE7))
            : const Icon(Icons.open_in_new, color: Colors.grey, size: 20),
      ),
    );
  }
}
