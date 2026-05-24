---
name: laser-snapshot
description: Manage diagnostic snapshots - full-system HTML reports per node (system, runtimes, certificates, network, kernel, logs). Snapshots are NOT data backups. Use /laser-backup for storage-volume restore points.
---

# laser-snapshot

A LaserData *snapshot* is a comprehensive diagnostic report of a deployment node - every runtime, every service, kernel parameters, certificate chains, network config, the last 2000 log lines per runtime, all packaged into an interactive HTML report. The Warden agent runs 30+ diagnostic categories in parallel, redacts secrets, and uploads the report to encrypted storage.

**A snapshot is not a backup.** It captures system state, not user data. For point-in-time recovery of storage volumes, see `/laser-backup`.

## Verbs

```sh
laser deployment snapshot list     --deployment-id $ID -o json
laser deployment snapshot create   --deployment-id $ID [--redact-secrets <true|false>] [--include-iggy <true|false>]
laser deployment snapshot download --deployment-id $ID --snapshot-id <id>
laser deployment snapshot delete   --deployment-id $ID --snapshot-id <id> --yes
```

`--division-id` / `--environment-id` / `--tenant-id` default to the active context. Pass them only if operating outside the default scope.

`create` accepts two optional booleans:

- `--redact-secrets <true|false>` (default `true`) - mask passwords, keys, tokens in the report.
- `--include-iggy <true|false>` (default `true`) - bundle an Iggy server data snapshot ZIP alongside the report.

Don't disable redaction without an explicit user request.

## Status lifecycle

`processing` → `completed`. Only one snapshot can be in flight per deployment at a time. After `create`, poll `snapshot list -o json` until the new entry has a non-null `completed_at`. Cap the wait at ~10 minutes. If it's still processing past that, surface a warning and stop polling.

## Plan limits

| Plan       | Snapshots / deployment | Retention |
|------------|:-:|:-:|
| Basic      | 3 | 7 days |
| Pro        | 5 | 14 days |
| Enterprise | 20 | 90 days |

Old snapshots fall out automatically once retention expires. You don't need to clean them up manually.

## Hard rules

1. `delete` is irreversible. Always show the targeted snapshot's `name` + `created_at` and ask the user to confirm before adding `--yes` and running.
2. `download` returns a presigned URL. Treat it as sensitive: show it once, suggest piping straight into a file (`curl -L "<url>" -o snapshot.zip`). Do not echo the URL into shared chat.
3. There is no `restore` verb on `snapshot`. Snapshots are diagnostic only. If the user wants to roll back data, hand off to `/laser-backup`.
4. Required permission: `deployment:read` to list/download, `deployment:manage` to create/delete.

## Common asks

- "diagnose deployment X" - `snapshot create`, then `snapshot download` once `completed_at` is set. Open the HTML in the browser.
- "show me snapshots" - `snapshot list -o json`, render: name, created, completed, status.
- "delete old ones" - list, filter by `created_at < now() - <window>`, delete one id at a time with per-entry confirmation. Never bulk-delete silently.

## Don't

- Don't conflate snapshot with backup. They are different verbs and different artefacts.
- Don't pass `--silent` here - you need the JSON.
- Don't tee the download URL into a file the user didn't name.
- Don't loop forever on `processing`. Cap at 10 minutes and stop.
