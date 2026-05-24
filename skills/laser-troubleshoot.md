---
name: laser-troubleshoot
description: Diagnose a struggling deployment. Pulls metrics, heartbeats, recent activity, runtime logs and access rules, summarises health, surfaces the likely root cause and a concrete next step.
---

# laser-troubleshoot

Argument: `<deployment-id>`. Optional `--division-id` / `--environment-id` / `--tenant-id` if the active context doesn't already cover them.

## Gather (in parallel where possible)

```sh
laser deployment get        --deployment-id $ID -o json
laser deployment heartbeats --deployment-id $ID -o json
laser deployment metrics    --deployment-id $ID -o json
laser deployment activity   --deployment-id $ID -o json
laser deployment logs       --deployment-id $ID --runtime iggy -o json
laser deployment access-rule list --deployment-id $ID -o json
laser deployment network    --deployment-id $ID -o json   # VPC / CIDR / per-cloud network detail
laser deployment task list  --deployment-id $ID -o json   # async tasks currently running on the deployment
```

Don't pass `--silent` - you need the JSON. Pipe it into reasoning, not into the user's terminal.

If the supervisor itself looks unhealthy (every supervisor-bound call fails or hangs), pass `laser deployment get --basic --deployment-id $ID -o json` to skip the supervisor lookup and read the core metadata only - useful when the runtime layer is the failing component.

## Check, in order

1. **Status** (`deployment get` → `status`). The terminal-ready state is `initialized`. The terminal-failure state is `failed`. Transient states: `creating`, `initializing`, `creating_subnet`, `securing_network`, `creating_load_balancer`, `configuring_load_balancer`, `configuring_dns`, `configuring_certificates`, `assigning_public_ip`, `waiting_for_nodes`, `deploying_nodes`, `bootstrapping_warden`, plus the lifecycle transitions `upgrading`, `extending`, `rolling_back`, `deleting`. Long stalls in any transient state are worth surfacing to the user. The precise threshold (10 minutes etc.) is a heuristic, not server-enforced. `rolling_back` specifically signals a botched upgrade or extend - check `activity` for the failed action that triggered the rollback.
2. **Heartbeats**. Each node × runtime should have a recent entry. Missing runtime → process not up. The "stale after N minutes" threshold is operator-set - quote the gap (`now - last_heartbeat`) and let the user judge. Use `--node-id <id> --runtime <iggy|connectors|connector|warden>` to page the history for one node × runtime when chasing a flapper.
3. **Metrics**. Same flag pair (`--node-id`, `--runtime`) drills into per-node-runtime history. Without them you get the deployment-wide summary. CPU/memory/disk thresholds (commonly 85/90/85%) are heuristic, not server-enforced. Quote the actual sample.
4. **Activity**. The last failed action explains most "why is it stuck" questions.
5. **Logs** (`laser deployment logs`). The full filter set is `--runtime`, `--node`, `--level`, `--message <substring>`, `--scope-filter`, `--from <iso>`, `--to <iso>`, `--page`, `--results` (defaults: page 1, 100 lines/page). Start broad with `--runtime iggy --level error`, narrow with `--message`, `--node`, and the time window. Quote the most recent error verbatim.
6. **Access rules**. If the user can't connect, the answer is usually "no ingress rule covers their IP" or "the rule's `valid_to` is in the past".
7. **Network** (`deployment network`). VPC + CIDR + per-cloud network detail. Useful when access-rule list looks fine but connectivity still fails - confirms the deployment's actual network topology.
8. **Tasks** (`deployment task list`). Async work in flight on the deployment (snapshots, backups, upgrades, extensions). A wedged task here often explains a wedged status.

## Output shape

Return a short, structured report:

```
status:        <state>           e.g. "initialized (since 2h ago)"
health:        <green|amber|red> e.g. "amber: cpu 92% sustained on n3"
last action:   <line from activity>
recent errors:
  - <quoted log line>
  - <quoted log line>
likely cause:  <one sentence>
next step:     <a concrete `laser ...` command>
```

If the deployment is fine, say so and stop. Don't pad.

## Likely-cause → next-step

- CPU or memory pegged: `laser deployment upgrade --tier <higher> --deployment-id $ID`.
- Disk near full: `laser deployment upgrade --storage-size-gb <n> --deployment-id $ID`.
- Need more nodes (cluster mode): `laser deployment extend --add-nodes <n> --deployment-id $ID` (separate from `upgrade`. `extend` only adds capacity, doesn't change tier or storage).
- Connectivity from caller IP: `laser deployment access-rule add --deployment-id $ID --name claude-<caller-handle> --cidr <caller>/32 --iggy-tcp --remarks "<context> from claude"` (toggle `--iggy-http` / `--iggy-websocket` / `--iggy-udp` if that's the listener the client uses. Rule needs at least one protocol).
- One runtime wedged on a specific node, but the deployment as a whole is up: `laser deployment runtime restart --runtime iggy --node-id <id>` (or `--runtime connectors`, or `--runtime connector:<type>:<key>` for a specific connector instance). `--node-id` is repeatable.
- Wedged in a non-terminal state (over 30 minutes): suggest `laser deployment delete --deployment-id $ID --yes` only after confirming with the user. Explain it's destructive.

Always print the command, ask `run this?`, wait.

## Don't

- Don't fabricate root causes. If the data doesn't point anywhere, say "no obvious cause, suggest `/laser-snapshot` for full-system diagnostic".
- Don't loop on `metrics` or `heartbeats`. One snapshot is enough for an initial diagnosis.
- Don't bulk-modify access rules. Per-entry confirmation only.
