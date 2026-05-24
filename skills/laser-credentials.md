---
name: laser-credentials
description: Read deployment admin credentials safely - reveal once, never echo into the conversation. Returns username + password only. Endpoints come from `laser deployment get`.
---

# laser-credentials

The CLI command `laser deployment credentials` returns the admin **username** and **password** for the deployment. That is all. Connection endpoints (domain, ports) live on `laser deployment get` - they are NOT part of the credentials response.

## Verb

```sh
laser deployment credentials --deployment-id $ID -o json
```

`--division-id` / `--environment-id` / `--tenant-id` default to the active context. Required permission: `deployment:credentials:read`.

## Response shape

The response carries exactly two string fields:

```json
{
  "username": "...",
  "password": "..."
}
```

That's the whole shape. The response does NOT contain `domain`, ports, transport URLs, or anything else. To get those, run `laser deployment get --deployment-id $ID -o json` separately - the resulting payload carries `domain`. Per-runtime / per-node ports surface elsewhere on that response.

## Hard rules

1. **Never echo the password back to chat.** Reveal it once into the user's terminal via `-o json`, tell them to copy it into a secret store, and stop. If the user later asks "what was that password again", refuse and have them re-run the command locally.
2. **Never tee the JSON output to a file** the user did not name. The CLI itself does not write credentials to disk.
3. Don't pass `-o name` (collapses the response to an ambiguous string) or `--silent` (suppresses output - defeats the point).
4. If the call returns 403, the user's role lacks `deployment:credentials:read`. Tell them, don't retry.

## Wiring an Iggy client

Endpoint info comes from `laser deployment get -o json`, not from `credentials`. The skill does not know the canonical Apache Iggy connection-string format off the top of its head. Consult the [Apache Iggy](https://iggy.apache.org/) client docs for the exact URL/string the user's chosen client library expects, then plug the username + password from `credentials` and the domain + ports from `deployment get` into that template.

When showing the user a snippet, leave the password as a `${IGGY_PASSWORD}` placeholder. Never inline it.

## Common asks

- "give me the password for deployment X" - run `credentials --deployment-id X -o json`, point the user at the JSON output, instruct them to copy `password` into a secret store. Do not paste it into chat.
- "build me a connection string" - fetch `credentials` + `deployment get` (for the domain), then assemble per the user's client library. Use a `${IGGY_PASSWORD}` placeholder for the secret.
- "rotate the credentials" - rotation is not a CLI verb today. If/when the platform adds it, this skill should be updated. For now, tell the user that.

## Don't

- Don't claim the credentials response includes `domain`, `tcp_port`, `http_port`, `ws_port`, `quic_port`, or any other endpoint field. It does not.
- Don't fabricate Iggy connection-string schemes (`iggy.tcp://`, `iggy+http://`, `iggy.ws://`, `iggy.quic://` - none of these are standard. Canonical Apache Iggy strings use `iggy://...` with query-string transport options). The exact form is client-library specific - look it up.
- Don't pass `--silent` here - the user wants the output.
