# Cubby 🗃️

A whimsical, Toot!-style iOS client for **[Memos](https://usememos.com)** — your self-hosted, Markdown-native note timeline. Native SwiftUI, no third-party dependencies.

A Memo is basically a toot: Markdown content, a visibility setting, tags, reactions, pins, and comments. So the Tweetbot/Toot! interaction model maps almost 1:1.

## What's in the box

- **Login** with server URL + a personal access token (Keychain-stored)
- **Home timeline** — pinned-first, newest-next, pull-to-refresh, infinite scroll
- **Compose** ("MEMO!") with a `Private / Protected / Public` visibility picker and Markdown
- **Per-memo actions** — react 👍, pin/unpin, delete (swipe or footer)
- **Detail view** — grouped reactions, comments thread, and a comment composer
- **Image attachments** rendered in a grid

## Requirements

- Xcode 15+, iOS 17+ target
- A running Memos instance (v0.24+ recommended; built against the v0.29 `/api/v1` schema)

## Setup

1. **Xcode → New → App**, SwiftUI lifecycle. Name it `Cubby`, set the deployment target to iOS 17.
2. Delete the auto-generated `ContentView.swift` and the default `…App.swift`.
3. Drag the contents of the `Cubby/` folder here into your target (keep the `Views/` group). "Copy items if needed" on.
4. Build & run. On first launch:
   - **Server URL:** e.g. `memos.example.com` (https is assumed)
   - **Access token:** create one on your server under **Settings → My Account → Access Tokens**

That's it — no CocoaPods/SPM packages to add.

## Running behind Tailscale (recommended)

Tailscale sits at the OS network layer, so the app needs zero Tailscale code — it just hits your server's address and traffic routes over WireGuard. Keep Memos off the public internet entirely.

**Do this on the host** so Memos is served over real HTTPS:

```
tailscale serve https / http://localhost:5230
```

Now point Cubby at `https://<machine>.<your-tailnet>.ts.net`. You get a valid cert via MagicDNS, so **no App Transport Security exception is needed** — you can delete the `NSAppTransportSecurity` block from `Info.plist`.

If you'd rather stay on plain HTTP (`http://…ts.net:5230`), keep the bundled `Info.plist`:
- In Xcode, **Target → Build Settings → Packaging → Info.plist File** = `Cubby/Info.plist` (or paste the same keys into the target's **Info** tab).
- Use the **`.ts.net` hostname, not the raw `100.x` IP** — the CGNAT range and IP literals aren't covered by the ATS exception. WireGuard already encrypts the hop, so this is safe for a private instance; HTTPS via `serve` is just cleaner.

The app maps connection failures (off-tailnet, DNS, server down) to a friendly "Is Tailscale connected?" state with a Retry button, so you're not left staring at a spinner when the tailnet is down.

## Architecture

```
CubbyApp.swift        @main, injects AppState
Models.swift         Codable types mirroring the Memos API
MemosClient.swift    async REST wrapper (list/create/delete/pin/react/comment)
AccountStore.swift   Keychain persistence for {serverURL, token}
AppState.swift       @MainActor ObservableObject — single source of truth
Theme.swift          accent color, Markdown render, the bouncy MEMO! button
Views/
  RootView.swift     login gate + tab shell + floating compose button
  LoginView.swift    onboarding
  TimelineView.swift home feed
  MemoRow.swift      one memo cell
  ComposeView.swift  new memo sheet
  MemoDetailView.swift  reactions + comments
  SettingsView.swift server info + sign out
```

## Design decisions worth knowing

- **Token auth, not password.** `POST /auth/signin` returns a short-lived access token tied to an HttpOnly refresh cookie — awkward to keep alive on-device. Personal access tokens are what MoeMemos and other clients use, and they don't silently expire. Password sign-in with token refresh is a clean future addition (`AuthService.SignIn` + `RefreshToken`).
- **Markdown is inline-only for now.** Uses `AttributedString(markdown:)` with `.inlineOnlyPreservingWhitespace`, so bold/italic/links/inline-code and line breaks render, but block elements (headings, fenced code, task lists) are shown as plain text. Swap in a block renderer (e.g. a small custom parser, or `swift-markdown` + custom views) when you want full fidelity.
- **Reactions are optimistic + additive.** Tapping 👍 calls `UpsertMemoReaction` and appends locally. Toggling a reaction off (via `DeleteMemoReaction` using the reaction's own id) isn't wired up yet.
- **Attachment URLs** are built as `{server}/file/{attachment.name}/{filename}`. This route has shifted between Memos versions — if images 404, that's the first line to check (`Attachment.url(server:)` in `Models.swift`).

## Endpoints used

| Action | Call |
|---|---|
| Validate / list | `GET /api/v1/memos?pageSize=&orderBy=&pageToken=&filter=` |
| Create | `POST /api/v1/memos` `{content, visibility}` |
| Delete | `DELETE /api/v1/memos/{uid}` |
| Pin | `PATCH /api/v1/memos/{uid}?updateMask=pinned` `{pinned}` |
| React | `POST /api/v1/memos/{uid}/reactions` |
| Comments | `GET` / `POST /api/v1/memos/{uid}/comments` |

## Nice next steps

- Photo picker → `CreateAttachment` → `SetMemoAttachments` on compose
- Tag sidebar / filter (the API's `filter` param already supports `"work" in tags`)
- Edit memo (`UpdateMemo` with an `updateMask=content`)
- Archived tab (`state=ARCHIVED`), search (`content.contains(...)`)
- Full block-level Markdown rendering
- Multi-account switching (the Keychain store currently holds one)

---

Unofficial, MIT-spirited, built as a starting point. Not affiliated with the Memos project.
