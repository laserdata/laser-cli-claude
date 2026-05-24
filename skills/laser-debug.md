---
name: laser-debug
description: Inspect the local laser CLI debug log to surface recent failures, transport errors, and slow requests. Useful when a CLI command misbehaves and the user wants to know why.
---

# laser-debug

The CLI writes a rolling daily debug log regardless of `--silent` / `--quiet`. This skill reads it.

## Where the log lives

- Linux: `~/.local/share/laser/logs/laser-YYYY-MM-DD.log`
- macOS: `~/Library/Application Support/laser/logs/laser-YYYY-MM-DD.log`

If `XDG_DATA_HOME` is set, replace `~/.local/share` with that.

## What to do

1. Find today's log file. If absent, fall back to the most recent file in the directory.
2. `tail -n 200` it. Each line carries a level + target + message.
3. Filter `WARN` and `ERROR` first - that's almost always what the user cares about.
4. Group by the log target (the module-path prefix on each line) so the user can see *where* the failure happened.
5. For HTTP transport errors, quote the URL + status. For API errors, quote `code` + `reason` + `title` + `status` from the problem+json body (see below).
6. End with a one-line next step:
   - `401` / `unauthorized` → key revoked, expired, or wrong-tenant. Confirm with `laser tenant key context -o json` (the same probe `auth login` uses). On a hard 401 the next step is `laser auth login --tenant-id <id>`.
   - `403 api_key_not_allowed` → user-scope endpoint hit with an API key (account / invitation / leave-tenant / etc.). Tell the user to perform that action from the Console. The CLI cannot. See `/laser-iam`.
   - `403` (any other code) → API key lacks scope. Run `laser tenant key context -o json` and inspect the `permissions` block (resolved tenant + per-division + per-environment grants) to see what's actually granted vs what the failing call needs. That's faster than guessing role assignments.
   - `409 idempotency_error` / `409 idempotent_request_in_progress` → client retried with the same `idempotency-key` but a different body (first case) or while the original request is still in flight (second case). Have the user retry shortly with the same body, or rotate the key.
   - `429` → rate limited. Quote the `retry-after` header if present and tell the user to back off.
   - timeout / connect error → check network reachability and the context's api-url (`laser context show -o json`). If it's wrong, re-run `laser auth login` to set it.

## Platform headers worth knowing

The CLI logs these on every request. They show up in the debug log and are useful when escalating:

| Header | Direction | What it tells you |
|---|---|---|
| `ld-api-key` | request | Bearer credential. Never log the value. The CLI redacts it. |
| `idempotency-key` | request | Optional client-supplied key (max 255 chars) on `POST` / `PUT` / `PATCH`. Server caches the response per `(api_key, idempotency-key)` for 10 minutes. The CLI does NOT set this by default. If you see it in the log, the user (or a wrapper) added it. |
| `ld-request` | response | Correlation id for the request (32-hex). Mirrors the `instance` field in the problem+json error body. **Quote this when filing a support ticket** - it's how the platform pivots to your specific call across services. |
| `idempotent-replayed: true` | response | The response was served from the idempotency cache, not re-run. Useful when explaining why a "create" returned an existing resource. |
| `link` | response | RFC 8288 pagination links (`first`, `prev`, `next`, `last`) on paged list responses. `laser` already walks pages via `--page` / `--results`. Surface this only when the user is hand-crafting curl calls. |
| `retry-after` | response | Seconds to wait. Sent on `429` and transient `5xx`. |
| `ld-tenant` / `ld-division` / `ld-environment` / `ld-deployment` / `ld-node` / `ld-config` / `ld-role` / `ld-subscription` | response | Created-resource id headers on the matching `POST`. The CLI surfaces these (e.g. `creation accepted for deployment id=<id>`). They originate here. |

## Error envelope (problem+json)

Non-`2xx` responses are served as `application/problem+json` (RFC 7807). All API errors carry this single shape:

```json
{
  "type": "about:blank",
  "title": "Invalid Email",
  "code": "invalid_email",
  "reason": "Invalid email address",
  "instance": "8f4a2b6c9d1e4f3a8b5c7d9e0f1a2b3c",
  "field": "email",
  "field_issues": [{ "code": "invalid_email", "reason": "malformed address", "path": "email" }],
  "status": 400,
  "retryable": false
}
```

- `code` - stable machine-readable error string. Branch on this, not on `title`.
- `title` - short human label derived from `code`.
- `reason` - long-form explanation.
- `instance` - mirrors the `ld-request` response header (the correlation id).
- `field` / `field_issues` - present only on validation (`400`). `field_issues[]` has per-field detail.
- `status` - mirror of the HTTP status so callers can branch on the body alone.
- `retryable` - `true` on `408 / 425 / 429 / 500 / 502 / 503 / 504`, otherwise `false`.

When summarising a failure, lead with `code` + `reason` + `instance`. The `instance` is the one piece of data support engineering can use to find your exact request in their logs.

## Tuning the log threshold

If the log isn't verbose enough, instruct the user to re-run the failing command with the file layer at trace level:

```sh
LD_LOG_FILE=trace laser <verb> ...
```

`LD_LOG_FILE` controls only the file layer. It does not pollute stderr. `LD_LOG` controls the stderr layer separately.

## Don't

- Don't paste raw API keys or tokens into chat, even from a log line. The log is normally clean of secrets, but a defensive scan is free insurance.
- Don't leave the log open in a tail loop. One snapshot is enough.
- Don't suggest enabling trace-level globally in `.bashrc` / `.zshrc`. It's diagnostic, not a permanent setting.
