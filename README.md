# Vlinix

Vlinix is a Flutter web app for auto detailing business management. It includes authentication, client records, vehicles, services, appointments, expenses, dashboard views, admin controls, avatar upload, and multilingual UI support.

## Stack

- Flutter / Dart
- Supabase Auth
- Supabase Postgres
- Supabase Storage
- Vercel deployment for the web build

## Required Environment Variables

Create these variables in Vercel before deploying:

```env
SUPABASE_URL=https://hjjsohmziddrlqggaimm.supabase.co
SUPABASE_ANON_KEY=your_supabase_publishable_or_anon_key
```

Use the Supabase publishable key (`sb_publishable_...`) or the legacy `anon public` key. Never use `service_role` or `sb_secret_...` in this Flutter web app.

## Vercel

This repository includes `vercel.json`, so Vercel can use the correct Flutter web build settings automatically.

If filling the Vercel screen manually, use:

```text
Application Preset: Other
Root Directory: ./
Build Command: bash scripts/vercel-build.sh
Output Directory: build/web
Install Command: echo "Flutter dependencies are installed during build"
```

## Local Web Build

```bash
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL=https://hjjsohmziddrlqggaimm.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_publishable_or_anon_key
```

## Notes for Reviewers

The deployed app requires a configured Supabase project and valid test account credentials. Database access is protected by Supabase Row Level Security policies.

## Public browser-only demonstration

The same Flutter screens can run with a local data adapter instead of Supabase:

```bash
CI=true flutter run -d chrome --dart-define=DEMO_MODE=true
```

The demo opens directly through **Explorar demonstração**. It includes fictional
clients, vehicles, services, appointments, completed jobs, tips, and expenses.
Visitors can create, edit, and delete local examples, complete service checklists,
change appointment status, inspect financial filters, and export spreadsheets.
Changes are stored only in the current browser under `vlinix:public-demo:v1`.
If browser storage is unavailable, changes stay in memory for the current session.
The persistent demo banner includes **Restaurar exemplo**, with confirmation,
to restore the fixtures and restart the walkthrough.

The demo never initializes Supabase and needs no account, password, API key, or
production environment file. Profile uploads, authentication, external maps,
address lookup, shop links, and realtime database subscriptions are unavailable
in this mode. Existing calendar exports are files generated locally, not calendar
invitations sent to another person.

### Reproducible static build

Use **Flutter 3.38.10 / Dart 3.10.9**:

```bash
bash scripts/build-demo.sh /Portfolio/demos/vlinix/
```

The resulting `build/web/` directory can be copied into the portfolio's static
output at `demos/vlinix/`. Its base path is `/Portfolio/demos/vlinix/`.
`--no-web-resources-cdn` includes the Flutter renderer in the output instead of
loading it from a third-party CDN. Do not pass `SUPABASE_URL` or
`SUPABASE_ANON_KEY` to a demo build.

The ordinary build remains the authenticated production application:
`scripts/vercel-build.sh` and its existing Supabase environment variables are
unchanged. `DEMO_MODE` defaults to `false`; local data is never used as a silent
fallback for production errors.
