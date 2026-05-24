---
name: laser-iam
description: Manage tenant identity + access - tenant config (join policy + invitation rules), API keys, members, roles, invitations, and cloud-account registrations. All operate at tenant scope.
---

# laser-iam

This skill covers the tenant identity surface that controls who can do what:

- **Tenant config** - join policy + invitation rules + claimed email domain. The "who can join, who can be invited" gate.
- **API keys** - non-human credentials, scoped to a role (and optionally a division), with optional source-IP allowlist.
- **Members** - human users that have joined the tenant, plus their role assignments.
- **Roles** - named bundles of permissions assignable to members and API keys.
- **Invitations** - pending invites for new members.
- **Cloud accounts** - external AWS/GCP accounts the tenant has registered (e.g. for BYOC).

All commands operate at tenant scope. `--tenant-id` defaults to the active context.

## Verbs

```sh
# Tenant config (join policy + invitation rules)
laser tenant config get
laser tenant config update    [--join-policy <invite_only|open|request_to_join>] [--block-external-invitations <true|false>] [--enforce-domain-only-invitations <true|false>] [--yes]

# API keys
laser tenant key list           [--name <filter>] [--page <n>] [--results <n>]
laser tenant key create         [--name <n>] [--role-id <id>] [--division-id <id>] [--expires-in-days <n>] [--validate-ip <true|false>] [--allowed-ip <ip>]
laser tenant key context                                                        # active key's role + permissions (uses the calling key)
laser tenant key update-security --api-key-id <id> [--validate-ip <true|false>] [--allowed-ip <ip>]
laser tenant key delete          --api-key-id <id> --yes

# Members
laser tenant member list         [--active <true|false>] [--page <n>] [--results <n>]
laser tenant member all                                                # includes inactive
laser tenant member permissions                                        # show available tenant/division/environment permission keys
laser tenant member update       --member-id <id> [--active <true|false>] [--role-id <id>]   # repeat --role-id to assign multiple
laser tenant member delete       --member-id <id> --yes

# Roles
laser tenant role list           [--page <n>] [--results <n>]
laser tenant role get            --role-id <id>
laser tenant role create         --name <n> [--description <text>] [--permission <key>]      # repeat --permission
laser tenant role update         --role-id <id> [--name <n>] [--description <text>] [--permission <key>]   # --permission REPLACES the set
laser tenant role delete         --role-id <id> --yes
laser tenant role members        --role-id <id> [--page <n>] [--results <n>]
laser tenant role assign         --role-id <id> --member-id <id>
laser tenant role revoke         --role-id <id> --member-id <id>

# Invitations
laser tenant invitation list     [--page <n>] [--results <n>]
laser tenant invitation create   [--email <email>] [--message <text>] [--role-id <id>]       # repeat --role-id
laser tenant invitation cancel   --invitation-id <id> --yes

# Cloud accounts
laser tenant cloud-account list      [--page <n>] [--results <n>]
laser tenant cloud-account get       --cloud-account-id <id>
laser tenant cloud-account create    [--cloud <aws|gcp>] [--name <n>] [--account-id <cloud-side-id>] [--region <r>] [--remarks <text>]
laser tenant cloud-account delete    --cloud-account-id <id> --yes
```

## Permissions

The tenant-scoped permission keys, with the endpoints they cover:

| Permission         | Required for                                                       |
|--------------------|--------------------------------------------------------------------|
| `info:read`        | `tenant get` / `tenant structure`                                  |
| `info:manage`      | `tenant update`                                                    |
| `audit:read`       | `audit ...`                                                        |
| `settings:read`    | `tenant cloud-account list` / `get`                                |
| `settings:manage`  | `tenant cloud-account create` / `update` / `delete`                |
| `role:read`        | `tenant role list` / `get` / `members`                             |
| `role:manage`      | `tenant role create` / `update` / `delete` / `assign` / `revoke`   |
| `member:read`      | `tenant member list` / `all` / `tenant invitation list`            |
| `member:manage`    | `tenant member update` / `delete` / `tenant invitation create` / `cancel` |
| `subscription:read`| billing-plan view                                                  |
| `subscription:manage` | plan changes                                                    |
| `billing:read`     | `tenant billing ...` read paths                                    |
| `billing:manage`   | billing settings updates                                           |
| `division:read`    | `division list` / `get`                                            |
| `division:manage`  | `division create` / `update` / `delete`                            |
| `api_key:read`     | `tenant key list`                                                  |
| `api_key:manage`   | `tenant key create` / `update-security` / `delete`                 |
| `notifications:read`  | `channel list` / `get` / `notifications`                        |
| `notifications:manage`| `channel create` / `update` / `delete` / `test`                 |

(Roles include the read perm of any matching `:manage` perm: e.g. `role:manage` implies `role:read`.)

There is no separate `cloud_account:*` permission - cloud-account endpoints route through `settings:*`.

There is no separate `invitation:*` permission - listing invitations uses `member:read`, creating / cancelling them use `member:manage`.

`tenant summary` is a special case: it requires only tenant membership (no specific `info:read` grant).

## Tenant config

`tenant config get` / `tenant config update` operate on the tenant-wide self-service settings.

Fields on the response:

- `join_policy` - one of `invite_only` (members must be invited), `open` (anyone with a matching email domain joins automatically), `request_to_join` (matching email domain requests admin approval).
- `block_external_invitations` - bool. When true, the tenant cannot send invitations to email addresses outside its claimed domain.
- `enforce_domain_only_invitations` - bool. When true, invitations whose email domain is NOT the tenant's claimed domain are rejected on submit.
- `email_domain` - the tenant's claimed email domain (read-only on this endpoint, `update` cannot change it).

`tenant config update` only mutates the first three fields. The path is `PUT /tenants/{tenant_id}/config`. On a TTY, the command reads the current values, prompts for any flag the user did not pass, prints a preview, and asks for confirmation. Pass `--yes` to skip the preview confirmation. Off a TTY, omitted flags keep the current value.

Hard rule: you cannot enable `block_external_invitations` or `enforce_domain_only_invitations` while the tenant has no claimed `email_domain`. The CLI rejects the call up front with `"tenant has no claimed email domain - cannot enforce domain-based invitation rules"`. If the user wants those toggles on, they need to claim + verify a domain first (not exposed by `tenant config update`, out-of-band today).

Common asks:

- "lock the tenant down to invite-only" - `tenant config update --join-policy invite_only`.
- "let anyone with our company email auto-join" - `tenant config update --join-policy open`. Make sure the email domain is set + verified first, otherwise `open` matches no one.
- "stop people inviting random gmails" - `tenant config update --block-external-invitations true --enforce-domain-only-invitations true`. Requires a claimed email domain (see hard rule above).

## Hard rules

1. **`tenant key create` returns the secret token once.** The response carries `id` plus a `token` field. The secret is `token`. Hand the user a copy-paste-once flow. There is no recovery if the user loses it.
2. **Don't echo any API key secret to chat.** Render it once into the user's terminal, instruct them to paste into a secret store, drop it.
3. **Role updates REPLACE the permission set.** `tenant role update --role-id <id> --permission <p>` overwrites the entire permission set with whatever `--permission` flags you pass. To add a single permission to an existing role, first read the role with `role get`, build the union locally, then send the full set.
4. **Member updates also REPLACE roles.** `tenant member update --role-id <id>` (repeated) overwrites the member's full role list. To assign one extra role without disturbing existing ones, prefer `tenant role assign --role-id <id> --member-id <id>`.
5. **`tenant key delete` and `tenant member delete` are destructive and require `--yes`.** Show name + id (and for keys, `name` + `role_name` + `division_name` (if scoped) + `expiry_at` + `created_at` from `key list`, the API does not currently expose a "last used" timestamp) before passing `--yes`. For members, deletion removes their tenant membership entirely.
6. **Source-IP restriction on API keys** (`--validate-ip true --allowed-ip 1.2.3.4` repeatable) is enforced server-side at every request. Lock down CI keys this way. Warn the user if they're about to create a long-lived key with `validate_ip=false`.
7. **Discover available permission keys with `tenant member permissions`.** Don't fabricate permission strings when authoring roles - the canonical list comes from this command.
8. **`tenant key context` answers "what can THIS key do".** It hits `GET /tenants/{tenant_id}/api_keys/context` using the calling key, and returns the key's metadata (id, name, role_id, role_name, division_id/name, validate_ip, allowed_ips, expiry_at, created_at, **user_id**) plus the resolved tenant / division / per-environment permission scopes. The `auth login` flow uses this same endpoint to validate that the pasted key is live, in-tenant, and not revoked. Only tenant membership is required - any key in the tenant can read its own context.
9. **`user_id` on the api-key record is the key's CREATOR, not the caller, not the key's owner.** It's recorded once when the key was minted and never rewritten. Don't tell the user "you are user X" based on it. Tell them "this key was minted by user X". For audit forensics, also cross-check against `laser audit --types api_key_created --correlation-id …`.
10. **API keys are rejected on user-scope endpoints with `403 api_key_not_allowed`.** Even when the calling key was minted by the same user. The closed set: account read / export / sign-out, listing your own sessions, listing your own invitations, invitation accept / reject, user activity, tenant creation, leaving a tenant, tenant deletion. Two security schemes exist - `ld_api_key` (tenant-scoped) and `session_cookie` (Console browser). User-scope paths only accept the cookie. Do not retry these via the CLI. Direct the user to the Console at <https://laserdata.cloud>.

## Common asks

- "create a CI key for the deploy bot" - `tenant role list -o json` to find a deploy-shaped role (or `role create` one), then `tenant key create --name deploy-bot --role-id <id> --expires-in-days 365 --validate-ip true --allowed-ip <ci-egress-ip>` (repeat `--allowed-ip` for each egress address). Capture the returned secret once, hand off, refuse to repeat.
- "add a new dev to the team" - `tenant invitation create --email <email> --role-id <developer-role-id> [--role-id <other>]`. The invitee accepts via the web UI. The CLI does not have an accept verb.
- "remove a member who left" - confirm with the user, `tenant member delete --member-id <id> --yes`. Their API keys and audit history remain. Check `tenant key list -o json` for keys still owned by them and rotate as needed.
- "what can role X do" - `tenant role get --role-id X -o json` shows the permission set. Cross-reference against the `tenant member permissions` catalogue.
- "register a BYOC AWS account" - `tenant cloud-account create --cloud aws --name "<acct-label>" --account-id <12-digit-aws-account>`. Once registered, the account id can be referenced from `deployment create-byoc --aws-account-id ...`.
- "rotate a leaked API key" - `tenant key delete --api-key-id <leaked-id> --yes`, then `tenant key create ...` for a replacement. There is no in-place rotate verb.
- "what can my current key do" / "check my permissions" / "is my key still valid" - `tenant key context -o json`. The response carries `api_key.role_name`, `api_key.expiry_at`, and a fully resolved `permissions` tree (tenant + per-division + per-environment). Use it to answer "do I have `deployment:manage` here" without trial-and-error 403s. A non-2xx (typically 401) means the key is revoked, expired, or wrong-tenant.
- "who created this api key" - `tenant key context -o json` returns `api_key.user_id` = the member who minted the key. Map it via `tenant member list -o json` to get a human name. (Do NOT phrase this as "the key belongs to user X" - keys aren't owned by members in the data model. The field only records the creator at mint time.)

## Don't

- Don't paste API key secrets into shared chat.
- Don't fabricate permission strings. Pull them from `tenant member permissions`.
- Don't bulk-modify roles or members. Per-entry confirmation only.
- Don't leave `--validate-ip false` for production / long-lived keys. Lock them down by source IP.
- Don't recommend deleting a role without first listing `tenant role members --role-id <id>` and checking that affected members have other access.
