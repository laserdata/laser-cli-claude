---
name: laser-channel
description: Manage tenant notification channels (slack, webhook, email). Create / get / list / update / delete / test / inspect delivered notifications. Channels are how the platform alerts a human when something happens to a deployment.
---

# laser-channel

Notification channels are tenant-level destinations the platform sends events to (deployment state changes, incidents, billing notices). The JSON shape returned by the API is:

```json
{
  "id": "...",
  "channel": "slack|webhook|email|sms",   // NOT named "kind" in JSON
  "name": "...",
  "destination": "...",                    // present on `get`, NOT on `list`
  "enabled": true,
  "remarks": "...",
  "created_at": "...",
  "updated_at": "..."
}
```

Note: `list` does NOT include `destination`. Only `get` does.

## Verbs

```sh
laser channel list                                                    -o json
laser channel get           --channel-id <id>                          -o json
laser channel create        --kind <slack|webhook|email>               \
                            --name <name>                              \
                            --destination <url-or-email>               \
                            [--remarks <text>]
laser channel update        --channel-id <id> [--name <n>] [--destination <d>] [--enabled <true|false>] [--remarks <text>]
laser channel delete        --channel-id <id> --yes
laser channel test          --channel-id <id>
laser channel notifications --channel-id <id> [--message-type <type>] [--page <n>] [--results <n>] -o json
```

The CLI's `--kind` flag also accepts `--kind sms`. Don't use it - see "Channel kinds" below.

`--tenant-id` defaults to active context. `list` and `notifications` accept `--page` / `--results` (defaults: page 1, 50/page).

## Channel kinds

The CLI's `--kind` flag lists four kinds: `slack`, `webhook`, `email`, `sms`. **Three actually deliver**, one is a no-op:

- `slack` - Slack incoming webhook URL. Destination = the hook URL.
- `webhook` - Generic HTTPS webhook. Destination = the target URL.
- `email` - Email recipient. Destination = the email address.
- `sms` - **Not implemented.** The dispatcher is a no-op for SMS. The CLI will accept `--kind sms` and the API will create the row, but no message is ever sent. Do not offer this kind to users.

`create` prompts for `--kind`, `--name`, `--destination` on a TTY when omitted. In agent / non-TTY mode pass them explicitly. Destination format is validated server-side. Rely on the validator rather than format-matching client-side.

## Hard rules

1. **Never** echo full webhook URLs back to chat after a channel is created. Slack incoming webhooks contain a token in the path. Generic webhooks may also embed secrets. Use `channel get -o json` only when the user explicitly asks for them.
2. `create` accepts `--yes` to skip the preview confirmation. Don't pass it - the user should see the final destination string before it lands. (Exception: scripted CI runs where the user pre-confirmed.) `update` does NOT have a `--yes` flag. It applies its diff without confirmation, so confirm with the user *before* invoking `update --destination`.
3. `delete` is destructive. The channel stops receiving notifications immediately. Show name + kind + destination before adding `--yes`.
4. After `create`, run `channel test --channel-id <id>` once and confirm a delivery landed before claiming the channel works. `test` exists for exactly this reason.
5. `update --destination` rotates the secret. Treat the same as create: confirm with the user, do not echo the new value.

## Common asks

- "alert me on Slack when deployment X breaks" - `channel create --kind slack --name "<deployment> alerts" --destination <hook-url> --remarks "<deployment> incidents"`, then `channel test`. Per-channel filtering by message type / scope IS supported via the platform's subscription system. A channel with no subscriptions receives every event for the tenant. Once subscriptions are attached, only matching events come through. Subscription management is not currently a CLI verb - flag this to the user if they need fine-grained filtering.
- "what channels do we have" - `channel list -o json`, render: id, channel (kind), name, enabled. (Note: `list` does NOT include `destination`. Run `channel get --channel-id <id>` if the destination is needed.)
- "stop alerting on the old PagerDuty webhook" - `channel update --channel-id <id> --enabled false` to pause without losing history, or `channel delete --channel-id <id> --yes` to remove.
- "show me what this channel got in the last week" - `channel notifications --channel-id <id> -o json`, optionally filter by `--message-type` (real values include `deployment_initialized` and `deployment_operation_failed`. For the full set, run unfiltered first and group by `message_type`).
- "test that channel" - `channel test --channel-id <id>`. The platform sends a fixed test message through the channel's transport.

## Don't

- Don't paste destinations into shared chat after creation. List endpoints, mask the secret bit.
- Don't fabricate `--message-type` filter values - they're platform-defined. Run `channel notifications -o json` once unfiltered to see what types exist on this tenant.
- Don't bulk-delete channels without per-entry confirmation.
- Don't pass `--silent` on `create` - the user wants the new channel id.
