---
name: laser-quickstart
description: >-
  From nothing to a first message on LaserData Cloud in one flow: install the CLI, sign in, create or pick a deployment with the price shown first, allow this machine, read the connection details, create a stream and topic, send a message and read it back, then clean up. Use when the user says set me up on LaserData, quickstart, try LaserData Cloud, or run this on LaserData Cloud.
---

# laser-quickstart

You are taking the user from nothing to a first message read back from LaserData Cloud. Chain the steps below, report what each one did in one line, and wait for approval before any change. Every command is from the existing skills, so each step points at the skill that holds the detail.

## Hard rules

1. Never create a paid deployment without showing the `deployment create preview` price and getting a yes. Say it is an estimate from list prices, not a quote.
2. Never put an API key or password in the chat or on a command line. The user runs `laser auth login` and `--reveal` in their own terminal.
3. Never widen access beyond the caller's own address.
4. Discover clouds, regions and tiers at runtime with `deployment create options`. Never guess them.
5. Parse `-o json`, never the table. Pass every value as a flag: Claude Code has no terminal, so the CLI does not prompt.
6. Deletes need the user's confirmation first, and only then `--yes`.

## Step 1. Install and sign in

```sh
command -v laser
laser version
laser auth status
```

If `laser` is missing, give the user the installer to run, then check again:

```sh
curl -fsSL https://cli.laserdata.cloud/install.sh | sh
```

If `laser auth status` fails, follow `/laser-onboard`. The user signs in with `laser auth login` in their own terminal. Where `LD_API_KEY` is already set (an agent or CI run), no login is needed: the CLI reads it, and `LD_WORKSPACE` and `LD_DEPLOYMENT` set the scope. Confirm with:

```sh
laser auth status
laser org show -o json
```

## Step 2. Pick or create a deployment

```sh
laser deployment list -o json
```

If one fits, offer it, run `laser deployment use <name>`, and skip to step 3. Otherwise ask what it is for.

- **Try it out:** the free starter. Say it is capped at 200 KB/s, which fits a first send and read but not load tests.
- **Load or memory tests:** a managed tier. Price it first.

Discover the values, then create through `/laser-deploy`:

```sh
laser deployment create options clouds -o json
laser deployment create options regions --cloud aws -o json
laser deployment create starter --cloud aws --region us-east-1 --new-env sandbox -o json
```

For a managed tier, run `laser deployment create preview` with the same flags `create managed` takes, show the price, and get an explicit yes before `create managed`. Then wait:

```sh
laser deployment watch -d <name> -o json
```

`watch` exits 0 whether the deployment came up or failed, so read `status` in the JSON. `initialized` is ready. `failed` goes to `/laser-troubleshoot`. Ask how long the deployment should live and note the time, because paid tiers bill by the second.

## Step 3. Allow this machine

```sh
laser deployment connect access-rule allow-my-ip -d <name> --protocol tcp
```

This admits the caller's address as a `/32` for 24 hours. The CLI says so when another rule already covers it. A free deployment already carries `0.0.0.0/0`. For a named rule with an expiry that matches the lifetime from step 2, use `access-rule add` with `--name quickstart`, `--remarks` and `--valid-to` as in `/laser-access`.

## Step 4. Connection details

```sh
laser deployment connect show -d <name> -o json
```

Show the connection string with the password masked. The user runs `laser deployment connect show -d <name> --reveal` in their own terminal and keeps the value in a secret store or an env file with mode 600. See `/laser-credentials`.

## Step 5. Create a stream and topic

```sh
laser stream create quickstart -d <name>
laser topic create quickstart events -d <name> --partitions 1
laser topic show quickstart events -d <name> -o json
```

Use these names unless the user gives others. Create nothing the user did not agree to. `/laser-streams` has the other stream, topic and message options.

## Step 6. Send a message and read it back

```sh
laser message send quickstart events -d <name> --message '{"hello":"laserdata"}' --key first
laser message read quickstart events -d <name> --partition 0 --kind first --count 10 --payload json -o json
```

`message send` needs the deployment manage permission. A send is never resent, so a timeout means check with `message read` before sending again. `message read` reads one batch and stores no consumer offset. It is the check that the quickstart worked: the JSON must hold the message just sent. Print the result as the proof.

If a command fails, read its exit code and hand off to `/laser-debug`. A connection that times out with no rule for the caller's address means step 3 did not take effect.

## Step 7. Wire the SDK

The CLI cannot create an agent session or keep a consumer running. Both are SDK work. Hand over to `laser-sdk-setup` (laser-sdk-plugin) with the connection string as `${LASER_CONNECTION_STRING}`. To run a program with the secret kept out of the chat, capture it in the same command:

```sh
LASER_CONNECTION_STRING="$(laser deployment connect show -d <name> --reveal -o json | jq -r .connection_string)" <program>
```

After the program runs, `laser session list --status active -o json` shows the sessions it started.

## Step 8. Clean up

Remind the user of the lifetime from step 2. On request:

```sh
laser topic delete quickstart events -d <name> --yes
laser stream delete quickstart -d <name> --yes
laser deployment delete -d <name> --yes
```

Show what goes with each, ask the user to type the name, and only then add `--yes`. A protected deployment emails a code: ask for it and run the delete again with `--code`. Deleting the deployment removes its data. Keep the deployment if the user means to carry on.

## Docs

- LaserData docs: <https://docs.laserdata.com>
- CLI: <https://docs.laserdata.com/cli> and <https://docs.laserdata.com/cli/commands>
- Laser SDK quickstart: <https://docs.laserdata.com/laser-sdk/quickstart> and connecting: <https://docs.laserdata.com/laser-sdk/connect>
- Access rules: <https://docs.laserdata.com/networking/access-rules>
- Docs MCP server (streamable HTTP, from `laser-sdk-plugin`): `https://laserdata-docs-mcp.fly.dev/mcp`. Use it to look up anything a skill does not cover.

## Don't

- Don't create a deployment, stream or topic the user did not ask for.
- Don't loop `message read` to tail a topic. Each call is one batch.
- Don't offer the free starter for load tests.
- Don't paste a connection string with its password into the chat.
