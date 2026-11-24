import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/locale_store.dart';
import '../../data/providers.dart';
import '../../data/theme_store.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider);
    final repo = ref.watch(profileRepoProvider);
    final current = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        children: [
          me.when(
            data: (p) => ListTile(
              leading: UserAvatar(name: p.displayName, url: repo.avatarUrl(p.avatarPath), radius: 28),
              title: Text(p.displayName),
              subtitle: Text('@${p.username}'),
              trailing: const Icon(Icons.edit),
              onTap: () => context.push('/settings/profile'),
            ),
            loading: () => const ListTile(title: LinearProgressIndicator()),
            error: (e, s) => ListTile(title: Text(context.tr('error'))),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.tr('language')),
            trailing: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'ar', label: Text(context.tr('arabic'))),
                ButtonSegment(value: 'en', label: Text(context.tr('english'))),
              ],
              selected: {current == 'en' ? 'en' : 'ar'},
              onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(s.first),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: Text(context.tr('darkMode')),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(v ? ThemeMode.dark : ThemeMode.light),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(context.tr('logout')),
            onTap: () async {
              await ref.read(supabaseProvider).auth.signOut();
            },
          ),
        ],
      ),
    );
  }
}
