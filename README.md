# Panchat 🐼

A WhatsApp-style chat app with its own identity: bamboo green, panda soul, Arabic-first (RTL) with English fallback.
Flutter app, Supabase backend (Auth, Postgres, Realtime, Storage). Android APK first; iOS and web later from the same code.

## What v1 does
- Email + password signup with a 6-digit email code, login, password reset by code
- First-run profile setup (username, display name, avatar)
- Realtime chats list with last message and unread badge
- 1:1 and group chats: text, images, voice notes, reply, delete for everyone
- Read receipts (one check = sent, two blue checks = read by everyone else)
- Online status and "typing..." through a private Realtime channel
- New chat by username search, groups (create, add/remove members, leave)

## Security
- `SUPABASE_URL` and `SUPABASE_ANON_KEY` come from `--dart-define` only. No key is in this repo. Only the **anon** key belongs in the app, never the service_role key.
- Session tokens are stored with `flutter_secure_storage` (Android Keystore backed).
- `usesCleartextTraffic=false`, and the app refuses to start unless the URL is `https://`.
- No token or session logging.
- Data access is enforced by Row Level Security in `supabase/schema.sql` (already applied to the project).

## Project layout
`lib/` holds the app (`core/`, `data/`, `features/`). `supabase/schema.sql` is the applied schema.
The repo does not commit the generated `android/` folder. `tool/patch_android.py` sets it up.

## Supabase setup checklist
1. Auth > Providers > Email: enable, and keep "Confirm email" ON.
2. Auth > Email Templates > "Confirm signup": make the email show the code, i.e. include `{{ .Token }}` (and "Reset password" too, for the reset flow).
3. Storage buckets `avatars` and `chat-media` and the Realtime policies come from `schema.sql`.
4. Realtime > Settings: leave "Allow public access" OFF so the private `conv:<id>` channels are enforced.

## Build locally
Needs Flutter (stable) and JDK 17.

```bash
flutter create --platforms=android --org com.panchat --project-name panchat .
python3 tool/patch_android.py
flutter pub get
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```
The APK lands in `build/app/outputs/flutter-apk/app-release.apk`.
Run on a device: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## GitHub Actions
`.github/workflows/build-apk.yml` builds the release APK on every push to `main` (or manually) and uploads it as the `panchat-apk` artifact.
1. Repo > Settings > Secrets and variables > Actions > add `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
2. Push to `main`. Download the APK from the run's Artifacts.
Notes:
- The workflow generates the Android project with `flutter create`, then runs `tool/patch_android.py` (package `com.panchat.app`, minSdk 23, permissions, HTTPS-only).
- The APK is signed with the debug key unless you add your own keystore. Fine for sideloading tests. Before wide distribution, create a release keystore, keep it out of git, and add signing config.
- Users must allow "install unknown apps" to sideload.

## Not in v1
Push notifications (needs Firebase + an Edge Function), delete account, group avatar editing, message search, iOS/web polish. See the roadmap in the project plan.
