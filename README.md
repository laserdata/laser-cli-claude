# laser-cli-claude

Claude Code skills for the [LaserData](https://laserdata.com) Cloud CLI. Drop them into `~/.claude/skills/` and Claude knows how to drive `laser` without you memorising the verbs.

## Skills

- `/laser-onboard` - install the binary, sign in, sanity-check.
- `/laser-deploy` - natural language to `laser deployment create-managed | create-starter | create-byoc` (plus `preview` for cost estimates, the two-step BYOC helpers `byoc setup` + `byoc validate`, and `upgrade`, `extend`, `retention`, `spend-limit`, `update`, `delete`). Cloud, region, tier and storage discovered from the API.
- `/laser-troubleshoot <id>` - metrics + heartbeats + activity + logs + network + tasks + access rules, summarised health, concrete next step (including per-runtime restart on a single node).
- `/laser-snapshot` - diagnostic HTML reports per node (system, runtimes, certs, network, kernel, logs).
- `/laser-backup` - point-in-time storage volume backups (network storage, AWS).
- `/laser-access` - access rules (firewall): list, add CIDRs with per-protocol toggles, delete.
- `/laser-credentials` - read deployment admin credentials (username + password) safely. Never echoed back.
- `/laser-context` - manage named CLI contexts (api-url + scope + key store).
- `/laser-config` - versioned deployment configs (iggy / connectors / warden / connector instances): list, view, create new versions, activate, delete.
- `/laser-channel` - tenant notification channels: slack, webhook, email (the `--kind sms` flag is accepted but the dispatcher is a no-op).
- `/laser-audit` - tenant audit log with filters (time, scope, user, types, correlation id).
- `/laser-iam` - tenant identity + access: tenant config (join policy + invitation rules), API keys, members, roles, invitations, cloud-account registrations.
- `/laser-billing` - tenant billing: subscription info, reports, invoices, invoice-PDF download (read-only on the CLI today).
- `/laser-debug` - read the local debug log and surface recent failures. Documents the platform headers (`ld-request`, `idempotency-key`, `idempotent-replayed`, `link`, `retry-after`) and the `application/problem+json` error envelope (RFC 7807: `type`, `title`, `code`, `reason`, `instance`, `field_issues`, `status`, `retryable`).

## Prereqs

```sh
curl -fsSL https://cli.laserdata.cloud/install.sh | sh
laser auth login --tenant-id <numeric-id>
```

`auth login` needs the **numeric tenant id** (issued by laserdata.cloud) plus an API key. Pass the key inline with `--api-key <key>` or let the CLI prompt you (masked). The tenant id can also come from `LD_TENANT_ID` or a saved context. CI / agents: export `LD_API_KEY` + `LD_TENANT_ID` instead.

CLI releases: <https://github.com/laserdata/laser-cli-releases>. Docs: <https://docs.laserdata.cloud>. OpenAPI 3.1 specs + interactive browser: <https://api.laserdata.cloud/docs> (Main / Audit / Notifier) and `https://supervisor-<cloud>-<area>.laserdata.cloud/docs` per region.

## One-shot install (binary + skills)

```sh
curl -fsSL https://cli.laserdata.cloud/install.sh | sh -s -- --with-cc-skills
```

Installs the `laser` binary AND runs the skill-pack installer (`cli.laserdata.cloud/claude.sh`) in one step. Idempotent: re-run to update both. The flag is optional - omit it to install only the binary.

## Install (Claude Code marketplace)

```
/plugin marketplace add laserdata/laser-cli-claude
/plugin install cli@laser
```

## Install (script)

```sh
curl -fsSL https://cli.laserdata.cloud/claude.sh | sh
```

Copies `skills/*.md` into `~/.claude/skills/`. Re-run to update.

## Manual

```sh
git clone https://github.com/laserdata/laser-cli-claude.git
cp -R laser-cli-claude/skills/* ~/.claude/skills/
```

## Source of truth

Every command, flag, tier name, cloud, storage class and plan limit referenced by the skills is verified against [the public docs](https://docs.laserdata.cloud) or `laser <verb> --help`. Skills query the API at runtime (`laser tenant get`, `laser cloud tiers`, etc.) instead of embedding static lists, so they stay correct as plans and regions change.

## Layout

```
laser-cli-claude/
├── .claude-plugin/marketplace.json   # plugin marketplace manifest
├── skills/                           # one slash-command per file
├── install.sh                        # copy skills/ into ~/.claude/skills/
├── LICENSE                           # Apache-2.0
└── README.md
```

## Contributing

PRs welcome. Skills are markdown with YAML frontmatter (`name`, `description`, body). Concrete `laser …` commands beat prose. Cite the docs section for any tier / cloud / storage / limit claim in the PR description.

## License

Apache-2.0. See `LICENSE`.
