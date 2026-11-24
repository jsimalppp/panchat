import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/misc.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/profile.dart';
import '../../data/providers.dart';

/// Used for first-run setup (setup: true) and later profile edits.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, required this.setup});
  final bool setup;
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _about = TextEditingController();
  Profile? _profile;
  Uint8List? _newAvatar;
  String _avatarExt = 'jpg';
  bool _loading = true;
  bool _busy = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await ref.read(profileRepoProvider).fetchMe();
      _profile = p;
      _name.text = p.displayName;
      // The auto-generated username has a random suffix; user can change it.
      _username.text = p.username;
      _about.text = p.about ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _newAvatar = bytes;
      _avatarExt = x.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    });
  }

  Future<void> _save() async {
    final username = _username.text.trim().toLowerCase();
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, context.tr('required'));
      return;
    }
    if (!isValidUsername(username)) {
      setState(() => _usernameError = context.tr('usernameInvalid'));
      return;
    }
    setState(() {
      _busy = true;
      _usernameError = null;
    });
    final repo = ref.read(profileRepoProvider);
    try {
      String? avatarPath;
      if (_newAvatar != null) {
        avatarPath = await repo.uploadAvatar(_newAvatar!, _avatarExt);
      }
      await repo.update(
        username: username,
        displayName: name,
        about: _about.text,
        avatarPath: avatarPath,
      );
      if (widget.setup) {
        await repo.markProfileSetupDone();
      }
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      if (widget.setup) {
        context.go('/');
      } else {
        context.pop();
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.code == '23505') {
        setState(() => _usernameError = context.tr('usernameTaken'));
      } else {
        showSnack(context, context.tr('error'));
      }
    } catch (_) {
      if (mounted) showSnack(context, context.tr('error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(profileRepoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setup ? context.tr('setupTitle') : context.tr('profile')),
        automaticallyImplyLeading: !widget.setup,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        if (_newAvatar != null)
                          CircleAvatar(radius: 56, backgroundImage: MemoryImage(_newAvatar!))
                        else
                          UserAvatar(
                            radius: 56,
                            name: _name.text,
                            url: repo.avatarUrl(_profile?.avatarPath),
                          ),
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            child: Icon(Icons.camera_alt, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(onPressed: _pickAvatar, child: Text(context.tr('changePhoto'))),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  maxLength: 50,
                  decoration: InputDecoration(labelText: context.tr('displayName')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _username,
                  autocorrect: false,
                  maxLength: 24,
                  decoration: InputDecoration(
                    labelText: context.tr('username'),
                    prefixText: '@',
                    errorText: _usernameError,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _about,
                  maxLength: 140,
                  decoration: InputDecoration(labelText: context.tr('about')),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(context.tr('save')),
                ),
              ],
            ),
    );
  }
}
