# Month-End

SAS programs for the monthly reporting cycle, and the reference material
needed to write against its tables.

## Layout

| Path | Contents |
|---|---|
| `sas/` | one file per program, bare code, copy-and-run |
| `docs/SAS_Tables_Knowledge.md` | data dictionary — grain, join map, reference files |
| `reference/tables/` | `PROC CONTENTS` of each source table |
| `reference/derivations/` | finalised SAS derivation for one column each, `TABLE__COLUMN.sas` |

## The two entities

| Convention | Entity A | Entity B |
|---|---|---|
| TB / EGL account string, segment 1 | `128` | `252` |
| TB shorthand | MBS | MSL |
| FRS9 `LEGAL_ENTITY_CODE` | `MBB-SG` | `MSL` |
| FRS9 `CO_CODE` | `001` | `003` |

## Environment

- SAS 9.4 M8 via Enterprise Guide, `SASApp`, host `SGDWVAPP01SAS` — a **remote
  server**, not the local PC. The server has its own `C:\Users\FNLNJE` profile,
  so `fileexist` on a desktop path returns 1 while pointing at a different,
  near-empty folder. Files reach the server through EG's Servers pane.
- `My SAS Files\PRETB` — trial balances, cleared monthly.
- `My SAS Files\posttb` — post-processing trial balances.
- `My SAS Files\eglfile` — the posting and reversal files HO returns.
- `My SAS Files\patch` — patch files awaiting verification, cleared monthly.
- `My SAS Files\<yymm>` — per-month outputs, created by `options dlcreatedir`;
  `<yymm>\glte` holds that month's GL uploads.
- The prompt variable is `PROC_DTE`, a Date prompt yielding `30JUN2026`. It
  collides in name with the `PROC_DTE` **column** on every FRS9 table: inside a
  DATA step reading one of those, `PROC_DTE` is the column and `&PROC_DTE` is
  the prompt.

## The server is runtime truth

`sas/` holds the reference copy of each program. The stored process on the SAS
server is what actually runs. A change is only real once it reaches the server —
committing here does not deploy it.

## What goes where

- A fact about a table, grain, key or derivation → `docs/SAS_Tables_Knowledge.md`
- SAS conventions and traps → the sas-writing skill, never this repo
- Environment behaviour → this file

**One fact, one home.** If something is recorded elsewhere, point to it rather
than restating it — a fact in two places becomes a contradiction the first time
one copy changes.
