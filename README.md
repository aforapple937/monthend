# SAS Workspace

SAS programs, and the reference material needed to write against the source
tables.

## Layout

| Path | Contents |
|---|---|
| `sas/` | one file per program, bare code, copy-and-run |
| `docs/SAS_Tables_Knowledge.md` | data dictionary — grain, join map, reference files |
| `reference/tables/` | `PROC CONTENTS` of each source table — the authority on columns, types, lengths |
| `reference/derivations/` | one column's derivation each (IT's Informatica logic in SAS), `TABLE__COLUMN.sas` |

## Environment

- SAS 9.4 M8 via Enterprise Guide, `SASApp`, host `SGDWVAPP01SAS` — a **remote
  server**, not the local PC. The server has its own user profile, so
  `fileexist` on a desktop path returns 1 while pointing at a different,
  near-empty folder. Files reach the server through EG's Servers pane.
- `My SAS Files\PRETB` — trial balances, cleared monthly.
- `My SAS Files\posttb` — post-processing trial balances.
- `My SAS Files\eglfile` — the posting and reversal files HO returns.
- `My SAS Files\patch` — patch files awaiting verification, cleared monthly.
- `My SAS Files\<yymm>` — per-month outputs; `<yymm>\glte` holds that month's
  GL uploads.
- The existing date prompt is named `PROC_DTE` (yields `30JUN2026`) — the same
  name as the `PROC_DTE` column on every FRS9 table.
