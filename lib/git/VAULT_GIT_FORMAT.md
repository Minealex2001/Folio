# Vault Git Format Specification (v1)

## Overview

Each Folio vault is stored as a local Git repository under `<vault-dir>/repo/.git`, with a plaintext working tree at `<vault-dir>/repo/`. The tree is encrypted only when transported (uploaded to cloud/WebDAV/P2P) as a git bundle.

## File Structure

```
repo/
├── tree.json                    # pageOrderByParent mapping
├── pages/
│   └── <id[0:2]>/<id>/          # Sharded by first 2 chars of pageId
│       ├── meta.json            # Page metadata (title, emoji, parentId, etc.)
│       ├── blocks.jsonl         # One JSON object per line, one block per line
│       └── comments.jsonl       # Per-page comments (LocalPageComment)
├── vault/
│   ├── meta.json                # Vault metadata (displayName, mcpReadablePageIds)
│   ├── acl.json                 # pageAcl (Map<pageId, Map<userId, role>>)
│   ├── integrations/
│   │   ├── jira.json
│   │   ├── youtrack.json
│   │   ├── trello.json
│   │   ├── github.json
│   │   ├── gitlab.json
│   │   ├── slack.json
│   │   ├── teams.json
│   │   ├── spotify.json
│   │   ├── discord.json
│   │   └── systemMedia.json
│   ├── templates/
│   │   └── <templateId>.json    # One file per template
│   ├── ai_chats/
│   │   └── <threadId>.json      # One file per AI chat thread
│   └── profiles/
│       └── <profileId>.json     # One file per local profile
└── attachments.manifest.jsonl   # LFS-style pointers: path → {sha256, sizeBytes}

# Legacy migration support (present only during/after migration):
└── legacy_revisions/
    └── <pageId>.jsonl           # Reconstructed per-page revision history (if too large for git commits)
```

## JSON Schema

### `tree.json`

Maps `parentId` → ordered list of child page IDs. Root pages use `""` (empty string) as key.

```json
{
  "": ["page-001", "page-002"],
  "page-001": ["page-003", "page-004"],
  "page-003": ["page-005"]
}
```

Replaces `VaultPayload.pageOrderByParent` entirely.

### `pages/<id[0:2]>/<id>/meta.json`

Page metadata, one file per page. ID sharding prevents a flat `pages/` directory from becoming unmanageable for large vaults.

```json
{
  "id": "page-001",
  "title": "Welcome",
  "emoji": "👋",
  "parentId": null,
  "isFolder": false,
  "trashedAt": null,
  "collabRoomId": null,
  "collabJoinCode": null,
  "lastImportInfo": null,
  "properties": [],
  "tags": []
}
```

**Note:** `collabJoinCode` is NOT synced (stays local-only in working tree, excluded from commits if needed via `.gitignore` or explicit filter).

### `pages/<id[0:2]>/<id>/blocks.jsonl`

One canonical (sorted-key, no pretty-print) JSON object per line. Each line is one `FolioBlock`. Block order is implicit (line order = block order).

```jsonl
{"id":"page-001_b0","type":"paragraph","text":"Hello world","appearance":{},"url":null}
{"id":"page-001_b1","type":"code","text":"console.log('git');","language":"javascript","appearance":{}}
```

Canonical encoding (sorted keys, no whitespace) ensures line-diffs are stable across platforms/Dart versions.

### `pages/<id[0:2]>/<id>/comments.jsonl`

Per-page comments (from `VaultPayload.comments` filtered by `pageId`). One `LocalPageComment` per line.

```jsonl
{"id":"cmt-001","pageId":"page-001","userId":"user-a","text":"Nice!","createdAtMs":1234567890}
```

### `vault/meta.json`

Vault-level metadata.

```json
{
  "displayName": "My Notebook",
  "mcpReadablePageIds": ["page-001", "page-002"],
  "aiActiveChatIndex": 0
}
```

### `vault/acl.json`

Page access control. Maps `pageId` → `{userId: role}`.

```json
{
  "page-001": {"user-a": "owner", "user-b": "viewer"},
  "page-002": {"user-a": "owner"}
}
```

Empty for single-user vaults.

### `vault/integrations/*.json`

One file per integration type, storing the full state object (connections, sources, etc.). Files are only present if non-empty.

- `jira.json`: `JiraIntegrationState`
- `youtrack.json`: `YouTrackIntegrationState`
- `trello.json`: `TrelloIntegrationState`
- `github.json`: `GitHubIntegrationState`
- `gitlab.json`: `GitLabIntegrationState`
- `slack.json`: `SlackIntegrationState`
- `teams.json`: `TeamsIntegrationState`
- `spotify.json`: `SpotifyIntegrationState`
- `discord.json`: `DiscordIntegrationState`
- `systemMedia.json`: `SystemMediaIntegrationState`

### `vault/templates/<templateId>.json`

One `FolioPageTemplate` per file.

### `vault/ai_chats/<threadId>.json`

One `AiChatThreadData` per file.

### `vault/profiles/<profileId>.json`

One `LocalProfile` per file.

### `attachments.manifest.jsonl`

LFS-style attachment pointers. Actual bytes are synced separately (reusing the existing cloud-pack content-addressed deduplication).

```jsonl
{"path":"attachments/img-001.png","sha256":"abc123...","sizeBytes":4096}
{"path":"attachments/video-001.mp4","sha256":"def456...","sizeBytes":1048576}
```

## Dropped/Changed from VaultPayload

- **`pageTombstones`**: Deleted. Git's native delete semantics (a file present at merge-base and absent on one side) replace this. UI shows "delete vs. modify" conflicts from Git merge results.
- **`syncClock` (Lamport counter)**: Deleted. Git's commit DAG provides ordering.
- **`pageRevisions`**: Deleted. Reconstructed from `git log --follow -- pages/<id>/blocks.jsonl` + `git show`.
- **`localProfiles`** (was `VaultPayload.localProfiles`): Split into `vault/profiles/` directory.
- **Comments**: Moved from a flat `VaultPayload.comments` list to `pages/<id>/comments.jsonl` per page.
- **AI chats**: Split from flat list to `vault/ai_chats/` directory.
- **Templates**: Split from flat list to `vault/templates/` directory.

## Encoding & Canonical Form

All JSON is encoded with:
- UTF-8
- Sorted keys (consistent across implementations)
- No pretty-printing (no unnecessary whitespace)
- No trailing newlines in individual JSON objects
- JSONL: one object per line, LF terminator

This ensures:
1. Git diffs are stable and readable (line-level changes are visible).
2. Merges by Git's native 3-way engine work correctly (no spurious reformatting conflicts).
3. Cross-platform consistency (Dart's `jsonEncode` with sorted keys, no trailing whitespace).

## Round-Trip Equivalence

A `VaultPayload` (schema v15) must serialize identically after round-trip:
1. `VaultPayload` → decompose to tree
2. `tree` → compose to `VaultPayload`
3. Result `VaultPayload.toJson()` should equal original's `toJson()` (modulo `syncClock`, `pageTombstones`, `pageRevisions` which are dropped/replaced)

Implemented as exhaustive Dart tests comparing field-by-field:
- Every page present in original must be present in reconstructed (same id, title, emoji, parentId, isFolder, trashedAt, blocks, properties, tags, collabRoomId)
- `pageOrderByParent` matches after reconstruction from `tree.json`
- Every integration state matches
- Comments match (re-collected from per-page files)
- Templates, AI chats, profiles match

## Git Commits

**Initial migration commit**: one big commit with the entire working tree.

**Synthetic history (optional)**: prior commits reconstructed from `pageRevisions` (one commit per revision, chronologically ordered).

**Ongoing commits**: every idle-debounce checkpoint (vault_session.dart `_appendRevisionSnapshotIfChanged`) becomes a local commit, touching only the files changed in that checkpoint.

**Commit message format** (for reconstructed/checkpoint commits):
```
Page: <title> (id: <pageId>)

Snapshot checkpoint at <timestamp>.
```

For synthetic history reconstruction (if `pageRevisions` exists), the commit message includes the revision timestamp.

## Migration Path

1. Read old `vault.bin` → decode to `VaultPayload`
2. Decompose to `repo/` working tree (this spec)
3. `git init` the directory
4. Create root commit(s):
   - Optional: replay `pageRevisions` as synthetic prior commits
   - Always: one final commit with current state
5. Upload result as bundle to cloud hub (encrypted with account DEK + AES-256-GCM)
6. Other devices detect `gitFormatVersion` migrated and clone from hub

## No `.gitignore`

The working tree is inside the app's private data directory (not user-visible, not synced by OS cloud-sync services). We do NOT use `.gitignore`; all tracked files are explicit. If `collabJoinCode` or similar local-only fields need exclusion, they are stored in a separate, untracked `local/` directory outside the repo, not mixed into the tree.

## Future: Attachment Bytes

The `attachments.manifest.jsonl` is Git-tracked; attachment bytes are stored separately (content-addressed, encrypted on wire) and synced as individual blobs. This is out of scope for the repo format itself — the manifest is the Git-versioned metadata, byte transport is separate transport-layer concern.

---

## Implementation Checklist (M1)

- [ ] Implement `VaultPayloadToTree` converter (Dart class)
- [ ] Implement `TreeToVaultPayload` converter (Dart class)
- [ ] Round-trip equivalence tests (property-based)
- [ ] Integrate with libgit2 FFI binding (init repo, stage files, commit)
- [ ] Hook into `vault_session.dart` idle-checkpoint path to emit commits
- [ ] Rebuild version-history UI on `git log`
- [ ] Test on single-device (no sync yet)
