---
name: laser-access
description: Manage deployment access rules (firewall) - list, add CIDRs with per-protocol toggles (Iggy TCP/HTTP/WebSocket/UDP), delete. Every deployment is fully isolated by default until rules are added.
---

# laser-access

Access rules are the deployment-level firewall: a CIDR block plus a set of per-protocol toggles deciding which Iggy listeners that block can reach.

**Default posture is fully isolated.** A new deployment accepts no traffic until you add at least one rule. The single exception is a Free tier managed deployment, which is created with a `0.0.0.0/0` rule open to keep the trial path frictionless.

## Verbs

```sh
laser deployment access-rule list   --deployment-id $ID -o json
laser deployment access-rule add    --deployment-id $ID --name <rule-name> --cidr <a/b> [--cidr <c/d> ...] [--ingress=true|false] [--remarks <text>] [--iggy-tcp] [--iggy-http] [--iggy-websocket] [--iggy-udp] [--valid-to <iso8601>]
laser deployment access-rule delete --deployment-id $ID --rules-id <id> --yes
```

`--division-id` / `--environment-id` / `--tenant-id` default to the active context.

`--name` is required (1-100 chars, letters / digits / `-` / `_` / `.` / `:` / space). `--cidr` is repeatable: pass it multiple times to cover several IP ranges in one rule. `--ingress` takes a bool value and defaults to `true`. Pass `--ingress=false` to create an egress rule. The four `--iggy-*` flags are independent boolean toggles - pass each protocol the rule should permit. `--remarks` is the human-readable note (the API field is `remarks`, not `description`).

## Rule shape

A rule has:

- `name` - required, unique within the deployment, case-insensitive. 1-100 chars: letters, digits, `-`, `_`, `.`, `:`, space.
- `cidr_blocks` - at least one valid IPv4 CIDR (CLI: repeat `--cidr`).
- `ingress` - `true` for inbound (the common case), `false` for egress. CLI default is `true`. The flag accepts a bool value, so `--ingress=false` creates an egress rule.
- `rules` - per-protocol booleans: `iggy_tcp`, `iggy_http`, `iggy_websocket`, `iggy_udp` (CLI: `--iggy-tcp`, `--iggy-http`, `--iggy-websocket`, `--iggy-udp`).
- `valid_to` - optional expiry timestamp (CLI: `--valid-to <iso8601>`, must be in the future when set).
- `remarks` - optional human-readable note (CLI: `--remarks`).

Server-side validation is the source of truth. If a field you need is not exposed by `access-rule add` flags, surface that to the user rather than silently dropping it.

## Plan limits

| Plan       | Rules / deployment |
|------------|:-:|
| Basic      | 3 |
| Pro        | 10 |
| Enterprise | 20 |

## Hard rules

1. CIDR widening is high blast-radius. Before adding `0.0.0.0/0` (open to the world), explicitly warn the user and ask for confirmation. Recommend the narrowest viable CIDR.
2. Every `add` should pass `--remarks` so future operators know why a rule exists. If the user didn't supply one, ask. Also ask the user to name the rule (`--name` is required and must be unique within the deployment).
3. Every `add` must enable at least one protocol (`--iggy-tcp`, `--iggy-http`, `--iggy-websocket`, `--iggy-udp`). A rule with no protocol toggles is a no-op. Ask the user which listener they want reachable from this CIDR.
4. Rule deletion is destructive - the protocol immediately stops accepting traffic from that range. Show the rule's `name` + `cidr_blocks` and confirm before adding `--yes`.
5. Required permissions:
   - List: `deployment:access:read`.
   - Add / delete: `deployment:access:manage`.

## Common asks

- "let me connect from my IP": resolve caller IP (`curl -s https://ifconfig.me`), then `access-rule add --name "<user>-laptop" --cidr <ip>/32 --iggy-tcp --remarks "<user> laptop"` (add other `--iggy-*` toggles if the client uses HTTP/WS/QUIC).
- "open this office network": confirm the office CIDR with the user (don't guess), then add with `--name`, `--cidr`, the relevant `--iggy-*` toggles, and `--remarks`.
- "lock down this deployment": list rules, confirm each one, delete one at a time.
- "what can reach this deployment right now": `access-rule list -o json`, render: name, cidr_blocks, protocols, valid_to.

## Don't

- Don't suggest `0.0.0.0/0` casually. Always favour `<ip>/32` or a known network range.
- Don't silently ignore expiry. If `valid_to` is in the past, surface that - the rule is dead.
- Don't bulk-delete without per-entry confirmation.
