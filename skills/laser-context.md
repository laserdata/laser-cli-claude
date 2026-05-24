---
name: laser-context
description: Manage named CLI contexts - api-url + tenant scope + key store. List, switch, create, rename, delete contexts and explain what each verb does.
---

# laser-context

A *context* bundles an api-url, an api-key (held in the OS keyring under an `api_key_name` recorded in the context), and an optional default scope (tenant / division / environment / deployment, plus an `insecure` flag for http URLs). One machine can hold many contexts. One is active at a time.

## Verbs

```sh
laser context list -o json
laser context current                 # the active name
laser context show [<name>] -o json   # full resolved config (key masked). name optional, defaults to active
laser context create <name> [--tenant-id <id>] [--division-id <id>] [--environment-id <id>] [--deployment-id <id>] [--insecure] [--activate]
laser context switch <name>           # alias: `laser context use`
laser context rename <old> <new>
laser context delete <name>           # removes config, leaves keyring entry
laser context set <field> <value>     # operates on the active context (override with --context)
```

`set` accepts `tenant_id`, `division_id`, `environment_id`, `deployment_id`, `insecure`. Id values are parsed as numeric. Passing an empty string is rejected as invalid input. There is no built-in "clear a scope id" verb today - to drop a scope the user has to delete and recreate the context, or wait for the CLI to add a clear-on-empty path. The api-url is bound by `laser auth login`, not by `set` - there is no `set api_url` field.

`create` does NOT take an `--api-url`. The api-url is resolved at login time from, in order: `--api-url <url>`, `LD_API_URL` env var, the existing context's stored URL, then the compiled-in default `https://api.laserdata.cloud`. `auth login` prompts only for the API key (it does NOT prompt for the URL). Pass `--api-url` if you need a non-default endpoint.

Login also requires an explicit **tenant id**, resolved (in order) from `--tenant-id <id>`, `LD_TENANT_ID` env var, or the existing context's saved `tenant_id`. With none of those it errors out. The login probe is `GET /tenants/{tenant_id}/api_keys/context`. A 2xx confirms the key is live, in-tenant, and not revoked, and the response (carrying role + permission scopes) is what the CLI prints back as "signed in - context '...', tenant #N, role …". The `/tenants` listing endpoint is NOT used for credential validation - don't claim it is. On success the key is stored in the OS keyring under the context. To inspect that role + permission set after the fact, use `laser tenant key context -o json` (see `/laser-iam`).

## Common asks

- "what context am I on" → `laser context current`, then `laser context show` (or `show <name>`) for the full picture.
- "switch to staging" → `laser context switch staging`. If the context doesn't exist yet, run `laser context create staging --tenant-id <id> --activate` followed by `laser auth login --context staging --api-url <staging-url>` (login prompts for the api-key. Pass `--api-url` if it differs from the default `https://api.laserdata.cloud` - `LD_API_URL` works too. If the context wasn't created with a `--tenant-id`, the login itself needs `--tenant-id <id>` or `LD_TENANT_ID`, since the validation probe is tenant-scoped).
- "set tenant to <id>" → `laser context set tenant_id <id>` (operates on active context. Pass `--context <name>` to target a non-active one).

## API keys are NOT stored in the context config file

The on-disk file is `<config_dir>/laser/config.toml` (resolves to `~/.config/laser/config.toml` on Linux, `~/Library/Application Support/laser/config.toml` on macOS). Mode is set to `0600` on Unix.

Only an account name (`api_key_name`) is persisted. The actual secret lives in the OS keyring (Keychain on macOS, Secret Service / gnome-keyring on Linux). The escape hatch `LD_ALLOW_INLINE_KEY=1` puts the secret into the toml file (mode 0600) when the keyring is genuinely unavailable (CI containers, headless boxes). Don't recommend it unless the keyring really doesn't exist.

## Hard rules

1. `delete` removes the on-disk record but **does not** purge the keyring entry. To wipe everything, suggest `laser auth purge --yes`.
2. `rename` moves the keyring account along with the config. Tell the user that.
3. Don't echo the api key value, even when `show` masks it. If a user asks "what's my key", point them at `laser auth login` to rotate.
