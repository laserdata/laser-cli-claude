---
name: laser-audit
description: Query the tenant audit log. Filter by time window, division, environment, deployment, subject user, author user, audit types, or correlation id. Useful for incident forensics, compliance reviews, "who did what when".
---

# laser-audit

The audit log is a single flat command (`laser audit`) with a rich filter set. One row per recorded action: who, when, what, against which scope, with the request's correlation id for cross-system tracing.

## Command

```sh
laser audit [--from <iso8601>] [--to <iso8601>] \
            [--division <id>] [--environment <id>] [--deployment <id>] \
            [--user <id>] [--author <id>] \
            [--types <comma,separated>] \
            [--correlation-id <id>] \
            [--page <n>] [--results <n>] \
            -o json
```

`--tenant-id` defaults to active context. **Both `--from` and `--to` are inclusive** (server uses `timestamp >= $from AND timestamp <= $to`). When chunking a sweep by day, advance `--from` past the last seen `timestamp` rather than relying on an exclusive upper bound. Defaults: page 1, 50 results per page.

`--user` filters by *subject* (the user the action targets). `--author` filters by *actor* (the user who performed the action). They differ: a tenant admin demoting a member shows the admin as `author` and the member as `user`.

`--types` is a comma-separated list. Discover the available type strings by running an unfiltered query first and grouping by the `type` field server returns. Do not invent type names.

## Hard rules

1. **Always** scope by time window. An open-ended `laser audit` on a busy tenant returns deep history and burns API quota for nothing. Default to the last 24 hours unless the user asks for more.
2. **Always** parse JSON (`-o json`) for forensic work. The table renderer truncates payload fields. The JSON has the full record.
3. Pagination is opt-in - results stop at `--results` per page. For multi-page sweeps, loop on `--page` and stop when a page returns zero rows.
4. Don't paste raw audit rows into chat verbatim if they contain emails, phone numbers, or destination URLs. Quote the action and ids. Redact PII unless the user explicitly asked for it.

## Common asks

- "who deleted deployment X yesterday" - `laser audit --deployment <id> --types deployment_deleted --from <yesterday-00:00Z> --to <today-00:00Z> -o json`, then map `author` user id to a member via `laser tenant member list`.
- "what did <user> do this week" - `laser audit --author <user-id> --from <monday-00:00Z> --to <sunday-23:59:59Z> -o json`, group by `type`.
- "trace this incident across systems" - the user has a correlation id from a Slack alert or log line. Run `laser audit --correlation-id <id> -o json` to get every audited action sharing that id (typically the full lifecycle of one user request).
- "compliance, every config activate in Q1" - `laser audit --types deployment_config_activated --from 2026-01-01T00:00:00Z --to 2026-04-01T00:00:00Z -o json`, paginate until empty.
- "what changed on <deployment> in the last hour" - `laser audit --deployment <id> --from <hour-ago-iso> -o json`, render: time, type, author, summary.

## Output shape

The actual JSON shape returned by `laser audit -o json` (one row per array element):

```json
{
  "type": "notification_channel_created",
  "name": "Notification channel created",
  "author": { "id": 617196980682097631, "name": "piotr@laserdata.com" },
  "user": null,
  "division": null,
  "environment": null,
  "deployment": null,
  "data": { ... type-specific payload ... },
  "correlation_id": "9123dc1a6dbe054b67a88a5129790dab",
  "timestamp": "2026-05-03T17:36:43.783112Z"
}
```

- `type` is the machine name (use this for `--types` filtering).
- `name` is the human label (good for rendering).
- `author` and `user` are objects (`{id, name}`) or null - not bare ids.
- `division` / `environment` / `deployment` are objects-or-null. The CLI's `--division` / `--environment` / `--deployment` filter flags take ids. Pull them from the inner `id` field when chaining queries.
- `data` (not `payload`) holds type-specific detail.
- `timestamp` is ISO-8601 (not `created_at`).
- No top-level row `id` field.

Render headline as `timestamp | type | author.name -> user.name | scope`, dump `data` only when the user asks for it.

## Don't

- Don't infer audit `--types` strings from naming conventions. They're tied to backend events. Use what the API actually emits.
- Don't paginate forever - cap at a reasonable depth (say 20 pages = 1000 rows) and surface "more results truncated, narrow the window" rather than spinning.
- Don't use the audit log as a metrics source. It records *actions*, not telemetry. Use `/laser-troubleshoot` for runtime data.
- Don't echo `correlation_id` back to chat as authoritative without quoting the source row - they're not user-friendly identifiers.
