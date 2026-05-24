---
name: laser-deploy
description: Translate a natural-language deployment request into the right `laser deployment create-managed | create-starter | create-byoc` invocation (plus `preview` for cost estimates before provisioning), then run it with the user's confirmation. Discovers cloud, region, tier and storage from the API rather than guessing.
---

# laser-deploy

Goal: turn a request like "spin up an Apache Iggy in eu-west-1 on the small tier" into a concrete `laser deployment create-managed …` call, with every flag filled from API discovery and user confirmation.

## Hard rules

1. **Never** invent ids, region codes, tier names or storage types. Discover them at runtime via `laser cloud …` and `laser tenant get`. CLI flag enumerations are not a contract - only what the backend currently provisions counts.
2. **Always** dry-run: print the final command and ask the user to confirm before executing.
3. **Always** parse JSON (`-o json`) when extracting ids. Never scrape the table renderer.
4. Refuse to execute if `laser tenant get -o json --silent` returns non-zero. Tell the user to run `/laser-onboard` first.
5. Do not pass `--api-key` inline. The CLI reads from the OS keyring (Keychain on macOS, Secret Service on Linux). Inline keys leak into shell history.
6. Do not pass `--yes` to a `create` call. On `create-managed` / `create-starter` / `create-byoc` it skips the interactive preview confirmation - we want the user to see the resolved plan before any cloud resource is provisioned.

## Live clouds

GA today: **AWS** and **GCP** ([docs](https://docs.laserdata.cloud/deployments)).

## Tier matrix

Tiers are gated by the tenant's plan. The cloud-aware list is `laser cloud tiers --cloud <c> --region <r> -o json` - that's the source of truth, since each tier object carries an `available` boolean keyed off the active tenant's plan. Read `laser tenant get -o json` for the plan name (top-level `plan`: `basic` / `pro` / `enterprise`) and the boolean feature toggles (see below).

Canonical strings to pass as `--tier` values (CLI flag values):

`free`, `small`, `medium`, `large`, `x-large`, `x-large2`, `x-large4`, `x-large8`, `x-large16`

Heads-up: the API JSON returned by `laser cloud tiers -o json` reports the same tiers under a `key` field with no hyphens (`xlarge`, `2xlarge`, `4xlarge`, `8xlarge`, `16xlarge`). When wiring discovery → `--tier`, map the API key to its hyphenated CLI form: `xlarge → x-large`, `2xlarge → x-large2`, `4xlarge → x-large4`, `8xlarge → x-large8`, `16xlarge → x-large16`. The first five (`free`/`small`/`medium`/`large` plus `x-large`/`xlarge`) are the same string modulo the hyphen.

Plan defaults (from the public tier-and-storage docs):

| Tier      | Basic | Pro | Enterprise |
|-----------|:-:|:-:|:-:|
| free      | 1 | 1 | 1 |
| small     | - | 3 | 3 |
| medium    | - | 3 | 3 |
| large     | - | 2 | 3 |
| x-large   | - | 1 | 3 |
| x-large2  | - | 1 | 3 |
| x-large4  | - | - | 2 |
| x-large8  | - | - | 2 |
| x-large16 | - | - | 2 |

Cluster kinds are `standalone` and `cluster`. Cluster mode is documented as "coming soon". Default to `standalone`.

## Storage matrix

Canonical strings to pass as `--storage-type` values (CLI flag values):

- `network-balanced` - general-purpose persistent storage (gp3 on AWS, pd-balanced on GCP).
- `local-ssd` - high-performance instance storage (NVMe, ephemeral).

Per-tier availability (always confirm against `laser cloud storages --cloud <c> --region <r> -o json` - that is the source of truth per tenant + cloud + region):

- `free`, `small`, `medium`: `network-balanced` and `network-optimized` are the documented options. `local-ssd` is also allowed for `small` and `medium`, but availability varies. The discovery API is authoritative.
- `large` and above: `network-balanced`, `network-optimized`, and `local-ssd`. `network-extreme` is gated to `x-large2` and above.

`network-optimized` and `network-extreme` are accepted by the `--storage-type` flag but availability varies by plan + cloud + region. Do not offer them unless `cloud storages -o json` returns the corresponding row with `available: true`.

Heads-up: the API JSON returned by `laser cloud storages -o json` reports `key` with underscores (`network_balanced`, `local_ssd`). When wiring discovery → `--storage-type`, swap underscores for hyphens.

## Discovery cheatsheet

```sh
# Active scope.
laser context current
laser tenant get -o json
laser tenant structure -o json

# Pick a division + environment.
laser division list -o json
laser environment list --division-id <id> -o json

# Confirm cloud + region + tier + storage are offered to this tenant.
laser cloud list                                                 -o json
laser cloud regions  --cloud aws                                 -o json
laser cloud tiers    --cloud aws --region eu-west-1               -o json
laser cloud storages --cloud aws --region eu-west-1               -o json
laser cloud clusters --cloud aws --region eu-west-1               -o json
```

## Variants

- **starter** (`create-starter`) - free single-node deployment for trials and learning. Backend requires `cloud` + `region`. Everything else has sensible defaults. Gated by `starter_available` on `tenant get`.
- **managed** (`create-managed`) - the standard deployment. User picks cloud + region + tier + cluster + storage. `--availability-mode multi-az` requires `multi_az_enabled: true` on `tenant get`. `--cluster cluster` requires `cluster_enabled: true`. `--dedicated true` requires `dedicated_enabled: true`.
- **byoc** (`create-byoc`) - bring-your-own-cloud. Requires `byoc_enabled: true` on `tenant get` plus per-cloud linkage flags: AWS account id + IAM role ARN + external id + VPC, or GCP project id + service account email + VPC name. **Always run the two-step `deployment byoc setup` + `deployment byoc validate` helpers first. Do NOT jump straight to `create-byoc`.** See "BYOC three-step flow" below.

Tenant-level booleans are top-level fields on `laser tenant get -o json`, not nested under a `features` object: `byoc_enabled`, `multi_az_enabled`, `dedicated_enabled`, `cluster_enabled`, `starter_available`, `has_payment_method`. Read them directly.

## BYOC three-step flow

`create-byoc` alone hands the cloud-side IAM linkage to the user as a "you must figure this out" problem. The CLI ships two helpers that bracket the create call:

1. **`deployment byoc setup`** - generates the cloud-side IAM setup instructions for a given tenant + division + environment + cloud + region. Returns the raw setup payload as JSON (external id, IAM policy doc, supervisor URL, etc.). Run BEFORE collecting creds. The user follows the printed steps in their AWS / GCP console.

   ```sh
   laser deployment byoc setup \
       --division-id <id> \
       --environment-id <id> \
       --cloud aws \
       --region eu-west-1 \
       -o json
   ```

   Endpoint: `POST /tenants/{tenant_id}/divisions/{division_id}/environments/{environment_id}/deployments/byoc/setup`. Capture the response - the `supervisor_url` and `external_id` fields feed straight into step 2.

2. **`deployment byoc validate`** - dry-runs the credentials against the supervisor BEFORE you ask the API to provision. This call goes DIRECTLY to the supervisor URL returned by setup (not through the control plane). The response carries a `valid` boolean and an optional `error` string. A `valid: false` payload becomes a non-zero exit code with the error string surfaced.

   ```sh
   laser deployment byoc validate \
       --division-id <id> \
       --environment-id <id> \
       --supervisor-url <url-from-setup> \
       --cloud aws \
       --region eu-west-1 \
       --aws-account-id <12-digit> \
       --aws-identity-arn <arn> \
       --aws-external-id <external-id-from-setup> \
       --aws-vpc-id vpc-... \
       -o json
   ```

   Note: `byoc validate` does NOT take `--aws-vpc-cidr` (the supervisor pulls it from the VPC itself). `create-byoc` does require `--aws-vpc-cidr`. The validate command's required flag set is the source of truth - mirror it. For GCP, swap the AWS flags for `--gcp-project-id` + `--gcp-service-account-email` + `--gcp-vpc-name`.

3. **`deployment create-byoc`** - actual provisioning. Same cloud-specific flags as validate plus `--aws-vpc-cidr`, the standard tier / region / storage / availability flags, and the deployment metadata (name, retention, spend limit, etc.). Only run this once `byoc validate` returns `valid: true`.

Hard rule: do NOT skip step 2. A failed cred at create time leaves a half-provisioned deployment that has to be cleaned up. Validate catches the same problem cheaply against the supervisor.

## preview (cost estimate)

`laser deployment preview` returns a projected monthly cost + per-component breakdown for a hypothetical deployment, **without provisioning anything**. Run it before `create-managed` / `create-byoc` when the user cares about cost. Permission: `deployment:read` (read-only, no `deployment:manage` required).

```sh
laser deployment preview \
    --division-id <id> \
    --environment-id <id> \
    --cloud aws \
    --region eu-west-1 \
    --tier small \
    [--storage-type network-balanced] \
    [--storage-size-gb 100] \
    [--availability-mode single-az] \
    [--nodes 3] \
    [--target-network-tput <MiB/s>] \
    [--telemetry-extra-days <n>] \
    -o json
```

Required: `--cloud`, `--region`, `--tier`. Everything else falls back to tier defaults (`--nodes` defaults to 3, `--telemetry-extra-days` to 0). Free tier short-circuits to `0` cost.

Endpoint: `POST /tenants/{tenant_id}/divisions/{division_id}/environments/{environment_id}/deployments/preview`.

Response carries `cloud`, `region`, `tier`, `nodes`, `instance` (cloud SKU name), `monthly_total_usd`, plus a `breakdown` with `compute_usd` / `storage_usd` / `network_usd` / `telemetry_usd` / `data_retention_usd`. **Estimate only**: computed from public list pricing without tenant discounts or final billing rules, may differ from the actual invoice. Surface that caveat to the user. Don't quote the number as binding.

Useful flow: `preview` → user confirms cost → `create-managed` with the same flags.

## Example: create-managed

User: "deploy iggy-prod, aws eu-west-1, small tier, single-az, 100 GB, network storage, in the platform division".

You:

1. Resolve scope:
   ```sh
   laser division list -o json | jq '.[] | select(.name=="platform")'
   laser environment list --division-id 12 -o json
   ```
2. Verify combination is offered to the tenant:
   ```sh
   laser cloud tiers    --cloud aws --region eu-west-1 -o json
   laser cloud storages --cloud aws --region eu-west-1 -o json
   ```
3. Print planned command (dry-run):
   ```sh
   laser deployment create-managed \
       --division-id 12 \
       --environment-id 47 \
       --name iggy-prod \
       --cloud aws \
       --region eu-west-1 \
       --tier small \
       --cluster standalone \
       --storage-type network-balanced \
       --storage-size-gb 100 \
       --availability-mode single-az \
       -o json
   ```
4. Ask `run this? (y/N)`. Wait.
5. On `y`: execute. Capture the deployment id from the JSON output.
6. Watch readiness (long-poll):
   ```sh
   laser deployment watch --deployment-id <id>
   ```
7. On failure: hand off to `/laser-troubleshoot <id>`.

## create-starter (the simplest path)

Required (per the public API docs): `cloud` and `region`. Everything else is optional.

```sh
laser deployment create-starter --cloud aws --region us-east-1 -o json
```

Defaults applied when omitted:

- `--tenant-id` and `--division-id` come from the active context (`laser context current`). The default division created with the tenant is used unless the user names another. If the context lacks a division, query `laser division list -o json` and ask the user to pick.
- `--environment-id` and `--environment-name` are both optional. If neither is passed, the backend creates a new environment named `sandbox`. To deploy into an existing environment, pass `--environment-id`. To name a new environment, pass `--environment-name`.
- `--deployment-name` is optional. The backend assigns one when omitted.

Reasonable defaults the skill may suggest (always confirm with the user before running):

- `--cloud aws`
- `--region us-east-1` (only if the user did not specify one)

Do not silently substitute these. Print the planned command, surface the defaults you applied, and wait for `y`.

Example for a brand-new user with an empty context:

```sh
laser deployment create-starter \
    --cloud aws \
    --region us-east-1 \
    -o json
```

This lands a free single-node Apache Iggy deployment in the tenant's default division, inside a fresh `sandbox` environment, with an auto-assigned deployment name.

## Post-create operations

Once a deployment exists, the relevant lifecycle verbs:

- **`upgrade`** - change tier and/or storage in place: `laser deployment upgrade --tier <new> --storage-type <new> --storage-size-gb <new> --deployment-id $ID`. Each flag is independent, pass only the dimension you want to change. Storage downsize is not supported.
- **`extend`** - add nodes to a cluster-mode deployment: `laser deployment extend --add-nodes <n> --deployment-id $ID`. The `--add-nodes` flag is repeatable for grouped node sets. Distinct from `upgrade` - this changes node count, not tier.
- **`retention`** - update telemetry retention: `laser deployment retention --telemetry-days <n> --deployment-id $ID`.
- **`spend-limit`** - cap or release the deployment's monthly spend: `laser deployment spend-limit --spend-limit <USD> --deployment-id $ID`, or `laser deployment spend-limit --clear --deployment-id $ID` to remove the cap.
- **`update`** - mutate metadata only: `laser deployment update [--description <text>] [--protected <true|false>] --deployment-id $ID`. Protected mode prevents accidental delete (the `delete` verb refuses unless `--protected false` is set first).
- **`delete`** - destructive. Accepts `--code <confirmation-code>` (the server refuses to delete a protected deployment unless this is supplied) and `--yes` to skip the local prompt. Two valid paths for a protected deployment: pass `--code <code>` directly, or run `update --protected false` first to lift the gate, then `delete`.

All of these go through the same preview / confirmation pattern as `create`. Show the planned command, ask `run this?`, wait. Don't pass `--yes` on the user's behalf.

## Don't

- Don't add `--silent` to the create call - the user wants the result. Use `--silent` only on probe/list calls inside the skill body.
- Don't loop manually on `deployment list` waiting for ready. `deployment watch` is the right primitive.
- Don't promise a tier/storage combo without checking `laser cloud tiers` + `laser cloud storages` first.
