---
name: laser-backup
description: Manage point-in-time backups of a deployment's storage volumes (network storage only, AWS today). List, create, restore, delete - with safety checks for destructive ops.
---

# laser-backup

A LaserData *backup* is a point-in-time snapshot of a deployment's storage volumes (EBS snapshots on AWS). Available on **network storage only** - local NVMe instance storage is ephemeral and cannot be backed up. Backups are the artefact you restore from after data loss. See `/laser-snapshot` for diagnostic reports of system state.

## Availability

- Network storage required (`network-balanced`). Deployments on `local-ssd` cannot be backed up.
- AWS today. GCP support is documented as future.
- Plan-gated: **Pro** and **Enterprise** only. Basic plan does not include backups.

| Plan       | Backups / deployment | Retention |
|------------|:-:|:-:|
| Basic      | - | - |
| Pro        | 3 | 30 days |
| Enterprise | 5 | 365 days |

## Verbs

```sh
laser deployment backup list    --deployment-id $ID -o json
laser deployment backup create  --deployment-id $ID
laser deployment backup restore --deployment-id $ID --backup-id <id>
laser deployment backup delete  --deployment-id $ID --backup-id <id> --yes
```

`--division-id` / `--environment-id` / `--tenant-id` default to the active context.

## Status lifecycle

`create` is asynchronous. After triggering, poll `backup list -o json` until the new entry's status reaches `completed`. Only one backup can be in progress per deployment at a time. If `create` fails because another is in flight, wait it out and retry.

## Hard rules

1. `restore` rolls the deployment's data back to the state captured in that backup. **Always** show the backup's `name` + `created_at` and ask the user to confirm before running. Spell out that data written between then and now will be lost.
2. `delete` is irreversible and frees a slot under the plan limit. Same confirmation pattern as restore.
3. Storage type matters. If the deployment is on `local-ssd`, refuse and explain that backup is only available on network storage. Suggest `laser deployment upgrade --storage-type network-balanced …` if conversion is needed.
4. Required permission: `deployment:read` (list), `deployment:manage` (create / restore / delete).

## Common asks

- "back up <deployment>" - `backup create`, then poll list until `completed`.
- "restore <deployment> to <backup-name>" - `backup list -o json` to resolve name → id, confirm, then `backup restore --backup-id <id>`.
- "delete old backups" - one id at a time with per-entry confirmation. Bulk delete is not supported and shouldn't be simulated.
- "set up scheduled backups" - there's no scheduled-backup primitive in the CLI today. Tell the user this is manual / external (cron + `laser deployment backup create`).

## Don't

- Don't conflate backup with snapshot. Different verb, different artefact, different recovery story.
- Don't suggest backup for a deployment on `local-ssd`. The operation will fail.
- Don't bulk-delete without explicit per-entry confirmation.
- Don't pass `--silent` - you need the JSON to track status.
