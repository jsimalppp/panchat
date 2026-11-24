import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/misc.dart';

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendVoice,
    required this.onTyping,
  });

  final Future<void> Function(String text) onSendText;
  final Future<void> Function(Uint8List bytes, String ext) onSendImage;
  final Future<void> Function(String path, int durationMs) onSendVoice;
  final VoidCallback onTyping;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  final _recorder = AudioRecorder();
  bool _hasText = false;
  bool _recording = false;
  bool _busy = false;
  int _recMs = 0;
  Timer? _recTimer;
  final _watch = Stopwatch();

  @override
  void dispose() {
    _recTimer?.cancel();
    _text.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _send() {
    final t = _text.text;
    if (t.trim().isEmpty) return;
    _text.clear();
    setState(() => _hasText = false);
    widget.onSendText(t);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final ext = x.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      setState(() => _busy = true);
      await widget.onSendImage(bytes, ext);
    } catch (_) {
      if (mounted) showSnack(context, context.tr('error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _attachMenu() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(context.tr('gallery')),
            onTap: () {
              Navigator.pop(c);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: Text(context.tr('camera')),
            onTap: () {
              Navigator.pop(c);
              _pickImage(ImageSource.camera);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) showSnack(context, context.tr('micDenied'));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      _watch
        ..reset()
        ..start();
      _recTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        setState(() => _recMs = _watch.elapsedMilliseconds);
        if (_watch.elapsedMilliseconds >= 290000) _stopRecording(send: true);
      });
      setState(() {
        _recording = true;
        _recMs = 0;
      });
    } catch (_) {
      if (mounted) showSnack(context, context.tr('error'));
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    _recTimer?.cancel();
    _watch.stop();
    final ms = _watch.elapsedMilliseconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
    if (!send || path == null || ms < 600) return;
    try {
      setState(() => _busy = true);
      await widget.onSendVoice(path, ms);
    } catch (_) {
      if (mounted) showSnack(context, context.tr('error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        color: Theme.of(context).colorScheme.surface,
        child: _recording ? _recordingRow(context) : _inputRow(context),
      ),
    );
  }

  Widget _recordingRow(BuildContext context) {
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => _stopRecording(send: false),
      ),
      const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
      const SizedBox(width: 6),
      Text(formatDuration(_recMs)),
      const Spacer(),
      CircleAvatar(
        backgroundColor: PandaColors.bamboo,
        child: IconButton(
          icon: const Icon(Icons.send, color: Colors.white),
          onPressed: () => _stopRecording(send: true),
        ),
      ),
    ]);
  }

  Widget _inputRow(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      IconButton(
        icon: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.attach_file),
        onPressed: _busy ? null : _attachMenu,
      ),
      Expanded(
        child: TextField(
          controller: _text,
          minLines: 1,
          maxLines: 5,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: context.tr('message'),
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) {
            final has = v.trim().isNotEmpty;
            if (has != _hasText) setState(() => _hasText = has);
            if (has) widget.onTyping();
          },
        ),
      ),
      const SizedBox(width: 6),
      CircleAvatar(
        backgroundColor: PandaColors.bamboo,
        child: IconButton(
          icon: Icon(_hasText ? Icons.send : Icons.mic, color: Colors.white),
          onPressed: _hasText ? _send : (_busy ? null : _startRecording),
        ),
      ),
    ]);
  }
}
