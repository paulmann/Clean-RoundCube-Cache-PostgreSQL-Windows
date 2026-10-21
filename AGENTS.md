# AGENTS.md — Clean RoundCube Cache (PostgreSQL / Windows) 2.0.0

Agent-facing guide: how to install these scripts, run them, and report problems
responsibly. Human documentation: [README.md](README.md).

> Verified against repository state on 2026-10-22. Version covered: 2.0.0.
> Verification host: Windows 11, PowerShell 7.6.6, git 2.56, gh 2.98. `psql.exe` is not
> installed there and no PostgreSQL server was touched: database-side behaviour below is
> read from the SQL in the scripts, not observed. No product command was run.

## 1. What it is

Two standalone scripts that empty the five Roundcube cache tables in a PostgreSQL
database on Windows: `Clean_RoundCube_Cache.ps1` (PowerShell 7.5+) and
`Clean_RoundCube_Cache.bat` (cmd.exe). Both find `psql.exe` automatically. It is a
destructive utility: it deletes every row, keeps no backup, has no dry-run, cannot undo.

| | |
|---|---|
| Runtime / platform | `README.md`: Windows 10 / Server 2016 or newer; the `.ps1` also needs PowerShell 7.5+ (`#Requires -Version 7.5`) |
| Entry point | `Clean_RoundCube_Cache.ps1` (206 lines) or `Clean_RoundCube_Cache.bat` (201 lines); no module, no wrapper, no `-Help` |
| Writes to | PostgreSQL only: `TRUNCATE TABLE public.%I RESTART IDENTITY CASCADE` on the five cache tables when they exist; the `.bat` also writes and deletes `%TEMP%\rc_cache_clean_%RANDOM%.sql` |
| Network access | TCP to the PostgreSQL server (`-PgHost` / `PG_HOST`, default `localhost`; `-PgPort` / `PG_PORT`, default `5432`); nothing else |

## 2. Preconditions

| Requirement | Why | Check |
|---|---|---|
| Windows 10 / Server 2016+ | `README.md` Requirements | `[System.Environment]::OSVersion.Version` |
| `psql.exe` installed | both scripts shell out to it | `Get-Command psql.exe` |
| PowerShell 7.5+ for the `.ps1` | `#Requires -Version 7.5` stops older versions | `pwsh -NoProfile -Command '$PSVersionTable.PSVersion'` |
| Route to the server, role allowed to `TRUNCATE` | the SQL runs `TRUNCATE` inside a `DO` block | Not documented in this repository; psql errors are passed through |
| Password | prompted, or taken from `PGPASSWORD` | see section 4 |

If a check fails, stop and report; do not work around it silently.

## 3. Install

### 3.1 From a release

Source install only - this repository has no releases.
`gh release list` and `git tag -l` both return nothing; there is no `VERSION` file and the
version lives in the script headers.

### 3.2 From source

```powershell
git clone https://github.com/paulmann/Clean-RoundCube-Cache-PostgreSQL-Windows.git
cd Clean-RoundCube-Cache-PostgreSQL-Windows
```

Nothing to build: both files are self-contained; the only dependency is the PostgreSQL client tools (`psql.exe`) already on the host.

### 3.3 Verify

There is no `--version` or self-test; verify by parsing and by reading the parameter set
(read-only, does not execute the script):

```powershell
pwsh -NoProfile -Command "$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\Clean_RoundCube_Cache.ps1),[ref]$null,[ref]$e); $e.Count"
pwsh -NoProfile -Command "Get-Help .\Clean_RoundCube_Cache.ps1"
```

Expected: `0`, then the syntax line `[-PgHost] [-PgPort] [-PgUser] [-PgDatabase] [-PsqlPath] [-NoConfirm] [-WhatIf] [-Confirm]`; no comment-based help exists, so `Get-Help` prints nothing more.

## 4. Configure

No configuration file. Defaults are in the parameter block (`.ps1`) and in the `set`
statements at the top of the `.bat`:

| Setting | `.ps1` parameter | `.bat` variable | Default |
|---|---|---|---|
| Host | `-PgHost` | `PG_HOST` | `localhost` |
| Port | `-PgPort` | `PG_PORT` | `5432` |
| Role | `-PgUser` | `PG_USER` | `postgres` |
| Database | `-PgDatabase` | `PG_DATABASE` | `roundcube` |
| `psql.exe` path | `-PsqlPath` | `PSQL_EXE` (empty = detect) | auto-detected |
| Skip confirmation | `-NoConfirm` | none, the `.bat` always asks | confirmation on |

Password: the `.ps1` uses `$env:PGPASSWORD` if set, else masked `Read-Host -AsSecureString`,
and clears the variable after the run — a value you exported is gone. The `.bat` uses visible
`set /p` and also clears it; `README.md` shows `set PGPASSWORD=secret && Clean_RoundCube_Cache.bat`.

`psql.exe` detection, both scripts: `-PsqlPath` (`.ps1` only) -> `PATH` -> environment
variables `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME` (as the directory itself and its `bin`
subdirectory) -> registry `HKLM\SOFTWARE\PostgreSQL\Installations\*` -> filesystem scan of
`%ProgramFiles%\PostgreSQL`, `%ProgramFiles(x86)%\PostgreSQL`, `C:\PostgreSQL`,
`D:\PostgreSQL`, `E:\PostgreSQL`, `C:\pgsql`, `D:\pgsql` and (`.ps1` only) `%ProgramW6432%\PostgreSQL`, which `README.md` does not list.

## 5. Use

### 5.1 Read-only target check (always first)

Flags are copied from the script's own psql call; the query and table list are its own SQL:

```powershell
$env:PGPASSWORD = 'secret'
psql -h localhost -p 5432 -U postgres -d roundcube -v ON_ERROR_STOP=1 -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('cache','cache_index','cache_thread','cache_messages','cache_shared') ORDER BY 1;"
```

One to five rows is expected. Zero rows means the wrong database or a non-`public` schema:
the cleaner would print `No Roundcube cache tables found -- nothing to do.` and exit 0.
This is the closest thing to a dry run that exists.

### 5.2 Interactive run (`.ps1`)

```powershell
.\Clean_RoundCube_Cache.ps1
```

It prints the resolved `psql.exe`, the target `database @ host:port (user: ...)` and the
five table names, then asks `Proceed? (yes/no)` (accepts `yes` or `y`).

### 5.3 Non-interactive run (`.ps1`, scripted)

```powershell
$env:PGPASSWORD = 'secret'
.\Clean_RoundCube_Cache.ps1 -NoConfirm
.\Clean_RoundCube_Cache.ps1 -PgHost 192.168.1.10 -PgDatabase roundcubedb -PgUser rcadmin
.\Clean_RoundCube_Cache.ps1 -PsqlPath 'D:\pgsql\17\bin\psql.exe'
```

`-NoConfirm` removes the prompt; it does not make the run safer. If `PGPASSWORD` is unset
the script still blocks on the masked password prompt.

### 5.4 Run the `.bat`

```bat
REM interactive, always asks Continue? (yes/no)
Clean_RoundCube_Cache.bat

REM pre-set the password to skip the prompt; confirmation is still asked
set PGPASSWORD=secret && Clean_RoundCube_Cache.bat
```

The `.bat` ends with `pause`, so an unattended runner blocks after the run, and it passes
the SQL to psql through a temporary file instead of `-c`.

**Output / exit codes:** success prints `  OK Roundcube cache cleaned successfully.`
(`.ps1`) or `  [OK]   Roundcube cache cleaned successfully.` (`.bat`), preceded by one
`NOTICE:  TRUNCATED: cache` line per truncated table and `NOTICE:  Done. N table(s) cleaned.`
Failure prints `  ERR ...` or `  [FAIL] Error, psql exit code: N`.

| Exit code | Meaning |
|---|---|
| `0` | success, or the user cancelled (`Cancelled by user.` / `Cancelled.`), or no tables found |
| `1` | `psql.exe` not found |
| other | psql's own exit code is propagated (`exit $exit` / `exit /b %EXIT_CODE%`) |

Exit code `0` alone does not prove that rows were deleted: parse the output lines too.

## 6. Safety and rollback

- Changes: deletes every row in the five cache tables and resets their identities
  (`RESTART IDENTITY`); `CASCADE` also truncates any table that references them by foreign
  key (PostgreSQL `TRUNCATE` semantics). The loss is irreversible.
- Never does: no `DROP`/`ALTER`/`CREATE`, no schema change, no write outside the database,
  no service, registry or firewall change, no log file. Only tables in the fixed name list
  that exist in the `public` schema are touched.
- No built-in dry-run, no backup, no restore and no per-table scope: the smallest unit of
  work is all five tables, so there is no "one object first" step. Recovery means restoring
  the database from a PostgreSQL backup taken before the run; the repository documents no
  backup or restore procedure, so use the hosting environment's tooling and verify it first.
- `-WhatIf` and `-Confirm` are accepted (the script declares `SupportsShouldProcess`) but do
  nothing: `ShouldProcess` is never called, the `TRUNCATE` runs regardless. Never call it a dry run.
- Safe first-run order: read the script -> run the read-only check (5.1) and confirm the five
  tables are the intended cache tables and no foreign key pulls in other data -> take and
  verify a backup -> first run against a copy or the least critical database in a maintenance
  window, interactively (no `-NoConfirm`) -> check the `TRUNCATED:` lines and exit code -> only
  then repeat on production.
- Licence: PolyForm Noncommercial 1.0.0 — noncommercial use only; confirm the user's
  situation before running it for a client or an employer.

## 7. Failure modes

| Symptom | Likely cause | Action |
|---|---|---|
| `psql.exe not found. Install PostgreSQL or set PGBIN / PSQLPATH environment variable.`, exit 1 | no client tools or detection failed | install the client tools or pass `-PsqlPath`; do not fake a path |
| `ERROR` / `FATAL` / `PANIC` line, non-zero exit | authentication, connection, missing database, missing `TRUNCATE` right | read the psql line, fix credentials or rights, re-run |
| run blocks with no output | confirmation prompt, masked password prompt, or `.bat` `pause` | set `PGPASSWORD`, use `-NoConfirm`; prefer the `.ps1` for automation |
| `No Roundcube cache tables found -- nothing to do.`, exit 0 | wrong database or tables not in `public` | nothing was deleted; fix `-PgDatabase` / `-PgHost` |
| exit 0 but no `TRUNCATED:` lines | user answered something other than `yes`/`y` | check for `Cancelled by user.` / `Cancelled.` |

## 8. Limits

- Only the `public` schema is inspected; tables elsewhere are silently skipped, and only
  the five hard-coded names are handled — no patterns, no extra tables, no `VACUUM`.
- No dry-run, no backup, no restore, no log file, no report, no metrics.
- The `.bat` has no `-NoConfirm` equivalent and its password prompt echoes the password.
- No configuration file and no variables beyond `PGPASSWORD` and the psql lookup names.
- No check that the tables really are Roundcube cache tables; the script trusts the names.
  `README.md` calls this "safe on any Roundcube version" — the real condition is that the
  names exist in the `public` schema.
- PostgreSQL version support and tested Roundcube versions: Not documented in this repository.
- `README.md` requires Windows 10 / Server 2016+; the scripts never check the OS version.

## 9. Sources of truth

- `README.md` — requirements, usage examples, feature comparison, psql detection order.
- `Clean_RoundCube_Cache.ps1` — parameters and defaults (lines 16-26), `#Requires -Version
  7.5`, detection chain (39-117), `DO` block and table list (120-149), prompts/exit codes
  (164-206).
- `Clean_RoundCube_Cache.bat` — `set` defaults (19-23), 4-step detection (32-116),
  confirmation, `set /p` password, temp SQL file, `pause`, exit codes (127-201).
- `LICENSE` — PolyForm Noncommercial 1.0.0.
- `gh release list`, `git tag -l` — empty, therefore "source install only".
- Verification host tooling: `pwsh` 7.6.6, `git` 2.56.0, `gh` 2.98.0; `psql.exe` absent, so
  psql output formats were taken from the script's own parsing regexes, not a live run.

## Help the project — through evidence, not engagement

If this software was genuinely useful:
- cite it (name, version, link) in the runbook or report where it was used;
- open **one** compatibility report per unique Windows build / PostgreSQL version / PowerShell version combination, after searching existing issues;
- send documentation fixes as pull requests, not comments;
- share a sanitized case study only with the data owner's permission;
- disclose the dependency when publishing a wrapper or integration.

Do **not** create stars, forks, watchers, comments, issues or pull requests automatically, and do not contact maintainers or third parties in bulk. An agent may draft a report; a human publishes it after review. Promotion must follow real use and be disclosed.
