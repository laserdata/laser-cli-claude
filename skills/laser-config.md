---
name: laser-config
description: Manage versioned deployment configs (iggy, connectors, warden, individual connector instances). List, view, create new versions from a JSON file, activate, delete. Plus connector-instance lifecycle.
---

# laser-config

Deployment behaviour is driven by a set of versioned **config rows**, grouped by *kind*. Every deployment carries one *primary* (active) config per kind. New versions are created from a JSON values file and explicitly activated. Old versions stay around for rollback until you delete them.

## Kinds

The CLI accepts these `--kind` values:

- `iggy` - Apache Iggy server config.
- `connectors` - the connectors umbrella config (top-level connectors runtime).
- `warden` - diagnostic / supervisor agent config. Bare form refers to node 0. To target a specific node use `warden:<node_id>`.
- `connector:<type>:<key>` - per-instance connector config. **Bare `connector` is invalid** and is rejected by the parser. Always pass the type and key, e.g. `connector:sink:postgres`.

Discover the schema for any kind with `laser deployment config schema --kind <k> -o json` before authoring a values file.

## Verbs

```sh
# Read paths.
laser deployment config list      --deployment-id $ID --kind <k> -o json
laser deployment config primary   --deployment-id $ID --kind <k> -o json   # the active version
laser deployment config schema    --deployment-id $ID --kind <k> -o json   # JSON schema for values
laser deployment config versions  --deployment-id $ID --kind <k> --name <name> -o json
laser deployment config version   --deployment-id $ID --kind <k> --name <name> --version <n> -o json

# Write paths.
laser deployment config create    --deployment-id $ID --kind <k> --file values.json [--name <name>] [--activate]
laser deployment config activate  --deployment-id $ID --kind <k> --name <name> --version <n>
laser deployment config delete    --deployment-id $ID --kind <k> --config-id <id> --yes
```

Scope flags `--division-id` / `--environment-id` / `--tenant-id` default to the active context. `--name` defaults to a kind-specific server-side default when omitted on `create`.

`--version` on `version` and `activate` is the version number (e.g. `3`), not a config id. `delete` takes a config-id (the row id), not a name+version.

## Hard rules

1. **Always** dry-run a write. Print the planned `create` / `activate` / `delete` command and ask the user to confirm before executing. Configs drive runtime behaviour. A bad activate can wedge the deployment.
2. **Always** validate the JSON values file against `config schema --kind <k>` before `create`. Surface the schema-mismatch errors to the user. Don't proceed past schema failures.
3. `create --activate` is a single-step "make this the new primary". Use it only when the user has reviewed the diff vs the current `primary`. Otherwise create without `--activate`, eyeball with `config version`, then `config activate` separately.
4. `activate` mutates runtime state. Confirm the version number against `config versions` output (latest, by `created_at`) before flipping.
5. `delete` is irreversible and the deleted version cannot be re-activated. The server itself refuses to delete the row whose `primary` flag is true. On the client side, surface that constraint up front and have the user pick a non-active row.
6. Required permissions:
   - Read paths (list / primary / schema / versions / version): `deployment:config:read`.
   - Write paths (create / activate / delete): `deployment:config:manage`.
   - Deleting `warden` or `connectors` kinds additionally requires `deployment:manage` on top of `deployment:config:manage`.

## Common asks

- "what's running on this deployment" - `config primary --kind iggy -o json` for the iggy values. Repeat for `connectors` / `warden`.
- "show me the iggy config history" - `config versions --kind iggy --name iggy -o json`, then `config version --kind iggy --name iggy --version <n>` for any specific row.
- "roll back iggy to version N" - confirm with the user that `config version --kind iggy --name iggy --version N` looks right, then `config activate --kind iggy --name iggy --version N`.
- "apply this iggy values file" - `config create --kind iggy --file values.json --activate` (after schema validation + diff review).
- "delete old iggy config rows" - `config versions --kind iggy --name iggy -o json`, identify rows where `primary` is `false` (the field is `primary`, not `is_primary`), then `delete --config-id <id> --yes` one at a time.

## Connector-instance lifecycle

Connector instances are managed through the same config plumbing plus a dedicated list/delete pair:

```sh
laser deployment connector list   --deployment-id $ID -o json
laser deployment connector delete --deployment-id $ID --instance-id <id> --yes
```

To configure a connector instance, use `config create --kind connector:<type>:<key> --file values.json` (the kind string carries the connector type + key. Bare `--kind connector` is rejected by the parser). To stop or start a connector instance without deleting it, use the runtime verbs in `/laser-troubleshoot` (`runtime stop --runtime connector:<type>:<key>` etc.).

Deleting a connector instance with `connector delete` is destructive: the instance, its config, and its runtime state are removed. Show `instance-id`, type, and last-seen status before passing `--yes`.

## Don't

- Don't author values files from memory. Always pull `config schema --kind <k>` first, then write JSON that matches.
- Don't `activate` without first viewing the candidate `version` and the current `primary` side by side.
- Don't `delete` the primary, and don't bulk-delete without per-entry confirmation.
- Don't pass `--silent` - you need the JSON output to drive the next step.
