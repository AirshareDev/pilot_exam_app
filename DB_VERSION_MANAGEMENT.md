# DB version management

## Update a read-only DB

When `catalog.db` or a qualification question DB is changed:

1. Replace the DB file under `assets/data/`.
2. Increase that file's `version` in `assets/data/database_manifest.json`.
3. Run the app normally. Uninstall is not required.

Example:

```json
"private_airplane.db": { "version": 2 }
```

The bundled copy replaces the installed copy only when its version is higher.
An existing installation from before this feature is replaced once to establish
its initial recorded version.

## user.db

`user.db` is copied only on first launch and is never replaced by an app update.
Therefore purchases, bookmarks, scores, history, and retry targets remain intact.
Future schema changes to `user.db` must be implemented as SQLite migrations,
not by increasing the asset version and replacing the file.

## Adding a qualification DB

Every new question DB must be added to the `databases` object in the manifest.
A DB without a manifest entry is installed on first launch but is not
automatically replaced later.
