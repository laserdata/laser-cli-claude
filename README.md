# laser-cli-claude

Claude Code skills for the [LaserData](https://laserdata.com) CLI. Install them and Claude drives `laser` for you: it discovers resources, proposes the exact command, and waits for your approval before anything changes.

The skills follow the console: the organization, its workspaces, their deployments, and the data inside each deployment.

## Skills

Getting started:

- `/laser-quickstart`: one flow from nothing to a first message read back on LaserData Cloud: install, sign in, a deployment with the price first, access for this machine, connection details, a stream and topic, send and read, then clean up.
- `/laser-onboard`: install the binary, sign in with an API key, pick the workspace and deployment scope, sanity-check.
- `/laser-context`: named contexts with their key, organization, workspace and deployment scope, and how the scope of a command is resolved.
- `/laser-workspace`: the workspace overview, its activity log, `find`, and workspace and environment settings.

Deployments:

- `/laser-deploy`: a starter, managed or BYOC `deployment create` from natural language, with values from `deployment create options`, a price from `create preview` first, `deployment watch` after, and the lifecycle under `deployment settings` (rename, move, protection, data access, metadata sync, retention, spend limit, plan upgrade) with requested against applied and `--wait`, then `deployment delete`.
- `/laser-troubleshoot`: health, metrics, heartbeats, throughput, logs, activity, tasks and access rules through `deployment monitor` and `deployment connect`, summarized into a likely cause and one next step.
- `/laser-snapshot`: diagnostic snapshots with `deployment monitor snapshot`.
- `/laser-backup`: point-in-time storage volume backups with `deployment settings backup`.
- `/laser-config`: configuration versions with `deployment settings config`, and runtime start, stop, restart and upgrade with `deployment settings runtime`.
- `/laser-connectors`: the Connectors and Backends tabs: the connector catalog, sources and sinks, and the backends that store projection data.
- `/laser-access`: access rules, the platform network, VPC peering and private endpoints with `deployment connect`, and which login a direct client signs in with.
- `/laser-credentials`: connection details with `deployment connect show`, masked in the chat. The deployment admin login by default, root only with `--root` for a key that also holds `deployment:manage`, rotation of either login with `deployment connect credentials rotate`, and how the CLI reaches data through the data access proxy or `--direct`.
- `/laser-cluster`: the Cluster, Users and Roles pages: node roster, clients, deployment users, governance roles, `whoami` and `capabilities`.

Data:

- `/laser-streams`: streams, topics, partitions, consumer groups, reading and sending messages, and dead letters.
- `/laser-agents`: agents, agent sessions, conversations, memory and knowledge graphs.
- `/laser-query`: queries, projections, writer schemas, forks and the key-value store.
- `/laser-filters`: consumer filters: try, register, revise, bind, pause, archive and drop.

Organization:

- `/laser-iam`: organization settings, members, invitations, roles, API keys and cloud accounts.
- `/laser-billing`: billing recipient, payment method, credits, invoices and PDFs, usage reports, marketplace agreements.
- `/laser-channel`: notification channels (Slack, webhook, email) for the organization or a workspace, and their subscriptions.
- `/laser-audit`: the organization audit log, filtered by time, event type, scope, member, API key or correlation id.
- `/laser-debug`: the error, exit code and local debug log of a failed command. Documents the platform headers (`ld-request`, `idempotency-key`, `idempotent-replayed`, `link`, `retry-after`) and the `application/problem+json` envelope (RFC 7807).

## Guardrails

Every skill:

- Discovers clouds, regions, compute profiles, storage, environments and names at runtime instead of guessing.
- Parses `-o json` output.
- Prints the exact command before any change and waits for approval.
- Asks you to confirm every destructive command, and only then adds `--yes`. Claude Code runs commands without a terminal, where the CLI refuses a destructive command that lacks `--yes`. A protected workspace, environment or deployment also needs the code its delete request emails.
- Never puts an API key, password or token on a command line or in the chat. Commands that print a secret (`org key create`, `deployment connect show --reveal`, with or without `--root`) are handed to you to run in your own terminal.

## Prerequisites

```sh
curl -fsSL https://cli.laserdata.cloud/install.sh | sh
laser auth login
laser workspace use main
```

`auth login` prompts for an API key, binds its organization, and stores the key in the OS keyring. For CI and agents, set `LD_API_KEY` for the key and `LD_WORKSPACE` and `LD_DEPLOYMENT` for the scope instead. No saved context is needed.

CLI releases: <https://github.com/laserdata/laser-cli-releases>. Docs: <https://docs.laserdata.com/cli>.

## One-shot install (binary and skills)

```sh
curl -fsSL https://cli.laserdata.cloud/install.sh | sh -s -- --with-cc-skills
```

Installs the `laser` binary and runs the skill-pack installer (`cli.laserdata.cloud/claude.sh`) in one step. Run it again to update both.

## Install (Claude Code marketplace)

```
/plugin marketplace add laserdata/laser-cli-claude
/plugin install cli@laser
```

## Install (script)

```sh
curl -fsSL https://cli.laserdata.cloud/claude.sh | sh
```

Copies each skill directory, `skills/<name>/SKILL.md`, into `~/.claude/skills/`. Run it again to update. `LASER_CLAUDE_DEST` changes the destination and `LASER_CLAUDE_REF` pins a tag or branch.

## Manual

```sh
git clone https://github.com/laserdata/laser-cli-claude.git
cp -R laser-cli-claude/skills/* ~/.claude/skills/
```

## Source of truth

Every command and flag in the skills matches `laser <group> --help` of the CLI release they target, and every limit or plan rule links to [the public docs](https://docs.laserdata.com). Skills read clouds, regions, compute profiles, storage and plans at runtime (`deployment create options`, `org show`), so they stay correct as plans and regions change.

## Layout

```
laser-cli-claude/
├── .claude-plugin/marketplace.json   # plugin marketplace manifest
├── skills/<name>/SKILL.md            # one skill per directory
├── install.sh                        # copy every skill directory into ~/.claude/skills/
├── LICENSE                           # Apache-2.0
└── README.md
```

## Contributing

PRs welcome. Skills are markdown with YAML frontmatter (`name`, `description`) and a body. Concrete `laser` command lines beat prose, and every command line must parse with the current CLI. Cite the docs section for any plan, tier, cloud, storage or limit claim in the PR description.

## License

Apache-2.0. See `LICENSE`.
