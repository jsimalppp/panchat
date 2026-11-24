import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../data/providers.dart';
import '../../features/auth/forgot_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/verify_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chats/chats_list_screen.dart';
import '../../features/group/group_info_screen.dart';
import '../../features/new_chat/new_chat_screen.dart';
import '../../features/new_chat/new_group_screen.dart';
import '../../features/settings/profile_edit_screen.dart';
import '../../features/settings/settings_screen.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

const _publicRoutes = {'/login', '/signup', '/verify', '/forgot'};

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseProvider);
  final refresh = _AuthRefresh(client.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = client.auth.currentSession;
      final loc = state.matchedLocation;
      if (session == null) {
        return _publicRoutes.contains(loc) ? null : '/login';
      }
      final done = client.auth.currentUser?.userMetadata?['profile_setup'] == true;
      if (!done) return loc == '/setup' ? null : '/setup';
      if (_publicRoutes.contains(loc) || loc == '/setup') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const PresenceKeeper(child: ChatsListScreen()),
      ),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),
      GoRoute(
        path: '/verify',
        builder: (c, s) => VerifyScreen(email: s.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(path: '/forgot', builder: (c, s) => const ForgotScreen()),
      GoRoute(path: '/setup', builder: (c, s) => const ProfileEditScreen(setup: true)),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(
        path: '/settings/profile',
        builder: (c, s) => const ProfileEditScreen(setup: false),
      ),
      GoRoute(path: '/new-chat', builder: (c, s) => const NewChatScreen()),
      GoRoute(path: '/new-group', builder: (c, s) => const NewGroupScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (c, s) => ChatScreen(conversationId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/group/:id',
        builder: (c, s) => GroupInfoScreen(conversationId: s.pathParameters['id']!),
      ),
    ],
  );
});
