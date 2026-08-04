# FRS9 Month-End

IFRS 9 ECL and EIR adjustment reporting for the Singapore entities. This repo
holds the SAS programs and the reasoning behind them.

## Layout

| Path | Contents |
|---|---|
| `sas/` | one file per program, bare code, copy-and-run |
| `docs/MER_11_Stored_Processes.md` | why each stored process works the way it does — §11.1 to §11.16 |
| `docs/MER_00_Cycle_and_Posting.md` | shared machinery: cycle sequence, EGL mapping, account string, posting mechanics, TB exports, HO's files |
| `docs/SAS_Tables_Knowledge.md` | data model — tables, grains, keys, conventions |
| `docs/Open_Items.md` | in-flight work, UAT, blocked questions |
| `docs/Accounting_Positions.md` | accounting positions and working notes |
| `docs/MER_12_NOSTRO_Enhancement.md` | NOSTRO ECL enhancement spec |
| `reference/tables/` | `PROC CONTENTS` of each source table |
| `reference/derivations/` | finalised SAS derivation for one column each, `TABLE__COLUMN.sas` |

## The two entities

| Convention | Entity A | Entity B |
|---|---|---|
| TB / EGL account string, segment 1 | `128` | `252` |
| TB shorthand | MBS | MSL |
| FRS9 `LEGAL_ENTITY_CODE` | `MBB-SG` | `MSL` |
| FRS9 `CO_CODE` | `001` | `003` |

Which convention sits on which table is in `docs/SAS_Tables_Knowledge.md`.

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
- A multi-value prompt arrives as `&NAME_count` plus `&NAME1..&NAMEn`, never as
  one delimited string. A single value still comes through as `&NAME1` with
  `_count = 1`. There is no `&NAME0`.
- `*ProcessBody;` must be the first line of any stored process.
- **A wrapper macro must not take the name of a SAS autocall macro.** `%STPEND`
  calls `%QLEFT`, which calls `%VERIFY`, so a stored process defining its own
  `%macro verify` has that macro re-entered from inside a macro expression where
  no step can execute. The code all runs, then `%STPEND` aborts and no result
  package is returned. Names to avoid: `VERIFY`, `LEFT`, `TRIM`, `CMPRES`,
  `QLEFT`, `QTRIM`, `DATATYP`, `SYSRC`. Prefix with the process name instead.

## The server is runtime truth

`sas/` holds the reference copy of each program. The stored process on the SAS
server is what actually runs. A change is only real once it reaches the server —
committing here does not deploy it.

## What goes where

- A fact about a table, grain, key or derivation → `docs/SAS_Tables_Knowledge.md`
- Anything about one stored process → its section in
  `docs/MER_11_Stored_Processes.md`
- Shared machinery → `docs/MER_00_Cycle_and_Posting.md`
- In-flight work, blocked questions → `docs/Open_Items.md`
- Accounting positions → `docs/Accounting_Positions.md`
- SAS conventions and traps → the sas-writing skill, never this repo
- Environment behaviour → this file

**One fact, one home.** If something is recorded elsewhere, point to it rather
than restating it — a fact in two places becomes a contradiction the first time
one copy changes.

## What the docs are for

They hold what the code cannot say: why it is done this way. Each process
section is **Confirmed** and **Open questions**, bullets only. Not included:
anything readable off the code, general SAS or accounting knowledge, inferences
stated as fact, or version history.
