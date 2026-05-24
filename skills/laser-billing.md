---
name: laser-billing
description: Read tenant billing surface - subscription/customer info, billing reports, invoices, and download invoice PDFs. Read-only on the CLI today.
---

# laser-billing

Tenant-scoped billing read paths. The CLI does not expose any payment-method, subscription-change, or refund verbs - just inspection and PDF download.

## Verbs

```sh
laser tenant billing info                                                 -o json
laser tenant billing reports          [--page <n>] [--results <n>]        -o json   # default 25/page
laser tenant billing report           --report-id <id>                    -o json
laser tenant billing invoices         [--page <n>] [--results <n>]        -o json   # default 25/page
laser tenant billing invoice          --invoice-id <id>                   -o json
laser tenant billing invoice-pdf      --invoice-id <id>  --output <path>
```

`--tenant-id` defaults to the active context.

`reports` and `invoices` default to **25 results per page**, not 50 like most list endpoints. Increase with `--results` when sweeping.

## `invoice-pdf` flag overload

`invoice-pdf` has **two** flags spelled `--output`:

- The global `-o, --output <OUTPUT>` flag is the format selector (table/json/yaml/name).
- `invoice-pdf` overloads the long form with a required filesystem destination: `--output <path>`.

In practice, run it as:

```sh
laser tenant billing invoice-pdf --invoice-id <id> --output /tmp/invoice.pdf
```

Don't combine with `-o json` - the response is a binary PDF, not JSON.

## Permissions

- `billing:read` - all read paths above.
- `billing:manage` - settings updates (no CLI verb today).
- `subscription:read` / `subscription:manage` - plan view / change (no CLI verb today, point users at the web UI if needed).

## Hard rules

1. **Never paste invoice line items, customer addresses, or tax ids into shared chat.** Bill data is sensitive (financial + PII). Render summary numbers (total, period, status) and tell the user to download the PDF locally for details.
2. `invoice-pdf` writes to disk at the path given. Confirm the path with the user before running, especially for shared-machine destinations.
3. The CLI cannot create a payment method, change plan, or pay an invoice. Don't suggest commands that don't exist - point users at the web UI for those flows.
4. Required permission for any of these reads: `billing:read`. If the user's role doesn't have it, the call returns 403. Tell them, don't retry.

## Common asks

- "what plan are we on" - `tenant get -o json` returns the top-level `plan` field (`basic` / `pro` / `enterprise`). For the full subscription block (status, period, etc.) use `tenant billing info -o json`.
- "show this month's bill" - `tenant billing reports -o json` for the list, then `tenant billing report --report-id <latest> -o json` for the breakdown. Reports are usage rollups, invoices are the corresponding paid or payable docs.
- "download the latest invoice" - `tenant billing invoices -o json --results 25 | jq '.[0].id'` to find the latest id, confirm with the user, then `invoice-pdf --invoice-id <id> --output ./invoice-<period>.pdf`.
- "how much have we spent this quarter" - `tenant billing reports --results 25 -o json`, sum the relevant rows by period. Don't fabricate totals. Quote the underlying response.

## Don't

- Don't echo invoice line items or customer billing details in chat.
- Don't tee `invoice-pdf` to a path the user did not explicitly choose.
- Don't suggest `tenant billing pay` / `tenant billing add-method` / `tenant billing cancel` - none exist on the CLI.
- Don't combine `invoice-pdf --output <path>` with `-o json` - the bytes you'd see are PDF binary.
