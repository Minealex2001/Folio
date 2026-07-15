# Why this package is vendored

This is a local fork of `firebase_auth_platform_interface` **9.0.2**, pulled in
via `dependency_overrides` (`path: vendor/firebase_auth_platform_interface` in
the repo root `pubspec.yaml`) instead of the published pub.dev package.

## The problem

On Windows, the native `id-token` and `auth-state` `EventChannel`
subscriptions dispatch from a background thread. The Flutter engine treats
platform-channel traffic from a non-platform thread as fatal
(`fml::KillProcess` -> `__fastfail(FAST_FAIL_INVALID_ARG)`, `0xC0000409`),
which crashes the process right after `Firebase.initializeApp()` /
`FirebaseAuth` initialize. Upstream tracking: firebase/flutterfire#18210,
firebase/flutterfire#18226, flutter/flutter#134346.

## The patch

A single opt-in static flag, `FirebaseAuthPlatform.disableIdTokenChannelOnWindows`,
skips both `EventChannel` subscriptions on Windows when set to `true`.
`currentUser` stays in sync via the method-channel responses of auth
operations; only `authStateChanges()`/`idTokenChanges()` stop emitting on
Windows. Folio sets the flag in [`lib/main.dart`](../../lib/main.dart) before
`Firebase.initializeApp()`.

Exactly two files carry the patch (search for `Local fork patch` to find
them):

- `lib/src/platform_interface/platform_interface_firebase_auth.dart` — declares
  the flag.
- `lib/src/method_channel/method_channel_firebase_auth.dart` — the
  `_shouldSkipAuthEventChannels()` gate used when subscribing to both channels.

## Re-syncing with a newer upstream release

This fork is **not** auto-updated by `flutter pub upgrade` — it's pinned by
path, so bumping `firebase_auth`/`firebase_auth_platform_interface` in
`pubspec.yaml` does **not** touch these files. When upgrading:

1. Diff this directory against the target `firebase_auth_platform_interface`
   version from pub.dev (or the flutterfire monorepo tag) to see what changed
   upstream.
2. Re-apply the two edits above on top of the new version (search for
   `Local fork patch` in the *old* vendored copy to find the exact diff to
   port forward).
3. Bump `version:` in `vendor/firebase_auth_platform_interface/pubspec.yaml`
   to match.
4. Check firebase/flutterfire#18210 / #18226 first — if upstream ships a real
   fix, drop this fork entirely and go back to the pub.dev package.
