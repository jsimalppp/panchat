import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../data/models/message.dart';
import '../../data/repositories/media_repository.dart';

class ReadTicks extends StatelessWidget {
  const ReadTicks({super.key, required this.status, this.failed = false});
  final int status; // 0 sending, 1 sent, 2 read
  final bool failed;

  @override
  Widget build(BuildContext context) {
    if (failed) return const Icon(Icons.error_outline, size: 16, color: Colors.red);
    if (status == 0) return const Icon(Icons.access_time, size: 14, color: Colors.grey);
    if (status == 1) return const Icon(Icons.done, size: 16, color: Colors.grey);
    return const Icon(Icons.done_all, size: 16, color: Color(0xFF1C8DFF));
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.status,
    required this.mediaRepo,
    this.senderName,
    this.replied,
    this.onLongPress,
    this.onRetry,
  });

  final Message message;
  final bool isMine;
  final int status;
  final MediaRepository mediaRepo;
  final String? senderName;
  final Message? replied;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = isMine
        ? (dark ? const Color(0xFF1F5B3A) : PandaColors.bambooSoft)
        : (dark ? const Color(0xFF26302A) : Colors.white);
    return Align(
      alignment: isMine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: message.failed ? onRetry : null,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (senderName != null && !isMine)
                Text(senderName!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12, color: PandaColors.bambooDark)),
              if (replied != null) _ReplyPreview(replied!),
              _content(context),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(formatClock(message.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (isMine && !message.isDeleted) ...[
                  const SizedBox(width: 4),
                  ReadTicks(status: status, failed: message.failed),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (message.isDeleted) {
      return Text('🚫 ${context.tr('deleted')}',
          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    }
    switch (message.type) {
      case 'image':
        return _ImageContent(path: message.mediaPath!, mediaRepo: mediaRepo);
      case 'voice':
        return _VoiceContent(
            path: message.mediaPath!, durationMs: message.durationMs ?? 0, mediaRepo: mediaRepo);
      default:
        return Text(message.body ?? '', style: const TextStyle(fontSize: 16));
    }
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview(this.m);
  final Message m;
  @override
  Widget build(BuildContext context) {
    final text = m.isDeleted
        ? context.tr('deleted')
        : m.type == 'image'
            ? '📷 ${context.tr('photo')}'
            : m.type == 'voice'
                ? '🎤 ${context.tr('voice')}'
                : (m.body ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: const BorderDirectional(start: BorderSide(color: PandaColors.bamboo, width: 3)),
      ),
      child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _ImageContent extends StatefulWidget {
  const _ImageContent({required this.path, required this.mediaRepo});
  final String path;
  final MediaRepository mediaRepo;
  @override
  State<_ImageContent> createState() => _ImageContentState();
}

class _ImageContentState extends State<_ImageContent> {
  late final Future<String> _url = widget.mediaRepo.signedUrl(widget.path);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 220,
        height: 220,
        child: FutureBuilder<String>(
          future: _url,
          builder: (c, snap) {
            if (snap.hasError) return const Center(child: Icon(Icons.broken_image));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            return GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(backgroundColor: Colors.black),
                  body: Center(
                    child: InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: snap.data!,
                        cacheKey: widget.path,
                      ),
                    ),
                  ),
                ),
              )),
              child: CachedNetworkImage(
                imageUrl: snap.data!,
                cacheKey: widget.path,
                fit: BoxFit.cover,
                placeholder: (c, u) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorWidget: (c, u, e) => const Center(child: Icon(Icons.broken_image)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VoiceContent extends StatefulWidget {
  const _VoiceContent({required this.path, required this.durationMs, required this.mediaRepo});
  final String path;
  final int durationMs;
  final MediaRepository mediaRepo;
  @override
  State<_VoiceContent> createState() => _VoiceContentState();
}

class _VoiceContentState extends State<_VoiceContent> {
  AudioPlayer? _player;
  bool _loading = false;
  bool _playing = false;
  Duration _pos = Duration.zero;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_player == null) {
        setState(() => _loading = true);
        final url = await widget.mediaRepo.signedUrl(widget.path);
        final p = AudioPlayer();
        _player = p;
        p.positionStream.listen((d) {
          if (mounted) setState(() => _pos = d);
        });
        p.playerStateStream.listen((s) {
          if (!mounted) return;
          setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
          if (s.processingState == ProcessingState.completed) {
            p.pause();
            p.seek(Duration.zero);
          }
        });
        await p.setUrl(url);
        if (mounted) setState(() => _loading = false);
      }
      if (_playing) {
        await _player!.pause();
      } else {
        await _player!.play();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.durationMs <= 0 ? 1 : widget.durationMs;
    final progress = (_pos.inMilliseconds / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 200,
      child: Row(children: [
        _loading
            ? const SizedBox(width: 32, height: 32, child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2)))
            : IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    size: 34, color: PandaColors.bamboo),
                onPressed: _toggle,
              ),
        Expanded(child: LinearProgressIndicator(value: progress, minHeight: 3)),
        const SizedBox(width: 8),
        Text(formatDuration(_playing || _pos > Duration.zero ? _pos.inMilliseconds : widget.durationMs),
            style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}
