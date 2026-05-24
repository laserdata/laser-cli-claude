---
name: laser-onboard
description: First-run setup for the LaserData Cloud CLI. Installs the binary, signs in, sanity-checks the active context.
---

# laser-onboard

You are walking the user through their first `laser` setup. Be terse. Each step prints what it did, then waits before moving on.

## Step 1 - install the binary

If `command -v laser` already returns a path, skip and report `laser already installed at <path>, version <output of laser --version>`. If the version is older than what `https://cli.laserdata.cloud/install.sh` ships, suggest `laser update` (in-place upgrade to the latest published release, no reinstall needed).

Otherwise:

```sh
curl -fsSL https://cli.laserdata.cloud/install.sh | sh
```

Verify:

```sh
laser --version
```

If `laser` is not on PATH after the install, the installer printed a hint about which shell rc to update. Read that hint back to the user.

## Step 2 - sign in

```sh
laser auth login --tenant-id <numeric-id>
```

**Two pieces are required on first login**: the **numeric tenant id** (issued by laserdata.cloud, e.g. `42`, NOT the tenant slug) and the **API key**. Pass the tenant id with `--tenant-id` and the key inline with `--api-key <key>` or let the CLI prompt you for it (masked). The login probe is tenant-scoped (`GET /tenants/<id>/api_keys/context`). Without a tenant id, the CLI cannot validate the key and bails with the error `"tenant id required: pass --tenant-id <id>, set LD_TENANT_ID, or run from a context that already has a tenant"`.

Resolution order for the tenant id: `--tenant-id` flag → `LD_TENANT_ID` env var → existing context's saved `tenant_id`. Any one of those satisfies the requirement on subsequent runs.

Interactive: the user pastes the API key generated at <https://laserdata.cloud>.

The CLI then validates the key by hitting `GET /tenants/<id>/api_keys/context` and prints back the resolved role on success. The key lands in the OS keyring (Keychain on macOS, Secret Service on Linux). Don't try to capture or echo it. After step 3, the user can run `laser tenant key context -o json` to see the full permission set bound to that key.

For non-interactive contexts (CI, agents, headless boxes), set both:

```sh
export LD_API_KEY=...
export LD_TENANT_ID=...
```

Use that pair instead of `auth login`. `LD_API_KEY` overrides the keyring lookup. `LD_TENANT_ID` (or a context saved with `laser context create --tenant-id <id>`) supplies the tenant the key authenticates against.

## Step 3 - confirm

```sh
laser tenant get -o json --silent && echo ok
laser tenant get
```

Show the tenant block. Confirm the active context with:

```sh
laser context current
```

## Step 4 - what's next

Tell the user they can now:

- `laser tui` - full-screen dashboard with mouse + keyboard.
- `laser <verb> --help` - discover any verb.
- `/laser-deploy` - create a deployment from natural language (`deployment preview` also estimates monthly cost without provisioning).
- `/laser-troubleshoot <id>` - diagnose a struggling deployment.

## OpenAPI reference (when you need raw HTTP)

The platform publishes an OpenAPI 3.1 spec for every service, with an interactive browser:

- Main + Audit + Notifier (one page, dropdown switches specs): <https://api.laserdata.cloud/docs>
- Per-region supervisor: `https://supervisor-<cloud>-<area>.laserdata.cloud/docs` (cloud ∈ `aws` / `gcp`, area ∈ `us` / `eu` / `ap`). The exact `supervisor_url` for a deployment comes back on `deployment get`.

Raw JSON specs sit at `/openapi/core.json`, `/openapi/audit.json`, `/openapi/notifier.json`, `/openapi/supervisor.json` on the corresponding hosts. Useful when generating a client or sanity-checking a payload shape. The CLI itself does not need them.

Stop. Don't keep going.
