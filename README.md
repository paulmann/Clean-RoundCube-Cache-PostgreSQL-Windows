# Clean RoundCube Cache — PostgreSQL / Windows

> PowerShell 7.5 and BAT scripts to **TRUNCATE all Roundcube cache tables** in PostgreSQL on Windows.  
> `psql.exe` is located **automatically** — no hardcoded paths required.

## Files

| File | Runtime | Lines |
|------|---------|-------|
| `Clean_RoundCube_Cache.ps1` | PowerShell 7.5+ | ~206 |
| `Clean_RoundCube_Cache.bat` | cmd.exe (any Windows) | ~201 |

---

## Feature Comparison

| Feature | `.ps1` (PowerShell 7.5) | `.bat` (cmd.exe) |
|---------|------------------------|------------------|
| Runtime requirement | PowerShell 7.5+ | Any Windows cmd.exe |
| Color-coded output | Yes (Cyan / Green / Red / Yellow) | Prefix tags: `[OK]` / `[FAIL]` / `[WARN]` |
| Typed parameters (`-PgHost`, `-PgUser` …) | Yes, full `[CmdletBinding]` | No (edit vars at top of file) |
| `-NoConfirm` silent mode | Yes (`-NoConfirm` switch) | No (always asks) |
| Pre-set password via env | `$env:PGPASSWORD` | `set PGPASSWORD=` before run |
| Password input | `Read-Host -AsSecureString` (masked) | `set /p` (visible in console) |
| Password zeroed after run | Yes (`$env:PGPASSWORD = $null`) | Yes (`set PGPASSWORD=`) |
| psql.exe auto-detection | 5-step chain (see below) | 4-step chain (see below) |
| SQL delivery to psql | Inline `-c` argument | Temp `.sql` file in `%TEMP%` |
| Atomicity | Single PL/pgSQL `DO $$` block | Single PL/pgSQL `DO $$` block |
| Table existence check | Yes (`information_schema.tables`) | Yes (`information_schema.tables`) |
| `RESTART IDENTITY CASCADE` | Yes | Yes |
| Tables cleaned | 5 (see list below) | 5 (see list below) |
| `ON_ERROR_STOP=1` | Yes | Yes |
| Exit code propagation | Yes (`exit $exit`) | Yes (`exit /b %EXIT_CODE%`) |
| Temp file cleanup | N/A | Yes (`del /f /q`) |
| `#Requires -Version 7.5` guard | Yes | N/A |

---

## Cache Tables Cleaned

```
cache
cache_index
cache_thread
cache_messages
cache_shared
```

Only tables that **actually exist** in your DB are processed — safe on any Roundcube version.

---

## psql.exe Auto-Detection

Both scripts search for `psql.exe` in the following order, stopping at the first match:

### PowerShell (.ps1) — 5 steps

1. **Explicit parameter** `-PsqlPath "C:\...\psql.exe"`
2. **System PATH** — `Get-Command psql.exe`
3. **Environment variables** (Machine, then User scope):  
   `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME` — checks both `<var>\psql.exe` and `<var>\bin\psql.exe`
4. **Windows Registry** `HKLM\SOFTWARE\PostgreSQL\Installations\*`  
   reads `Base` value, sorts keys by version **descending**, tries newest first
5. **Filesystem scan** of common root directories, subfolders sorted by `LastWriteTime` **descending** (newest PostgreSQL install wins):
   - `%ProgramFiles%\PostgreSQL`
   - `%ProgramFiles(x86)%\PostgreSQL`
   - `C:\PostgreSQL`, `D:\PostgreSQL`, `E:\PostgreSQL`
   - `C:\pgsql`, `D:\pgsql`

### BAT (.bat) — 4 steps

1. **System PATH** — `for %%I in (psql.exe)`
2. **Environment variables** via `reg query` (Machine then User):  
   `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME`
3. **Windows Registry** `HKLM\SOFTWARE\PostgreSQL\Installations\*` — newest key name wins
4. **Filesystem scan** using `dir /B /OD /AD` (oldest-to-newest by default, last match = newest)  
   Same root list as PS1

---

## Usage

### PowerShell

```powershell
# Interactive (confirms before run, prompts for password)
.\Clean_RoundCube_Cache.ps1

# Silent / scripted (password pre-set in env)
$env:PGPASSWORD = 'secret'
.\Clean_RoundCube_Cache.ps1 -NoConfirm

# Custom connection
.\Clean_RoundCube_Cache.ps1 -PgHost 192.168.1.10 -PgDatabase roundcubedb -PgUser rcadmin

# Explicit psql path
.\Clean_RoundCube_Cache.ps1 -PsqlPath 'D:\pgsql\17\bin\psql.exe'
```

### BAT

```bat
REM Interactive
Clean_RoundCube_Cache.bat

REM Pre-set password to skip prompt
set PGPASSWORD=secret && Clean_RoundCube_Cache.bat
```

---

## Requirements

- Windows 10 / Server 2016 or newer
- PostgreSQL client tools (`psql.exe`) installed
- Network access to PostgreSQL server
- For `.ps1`: **PowerShell 7.5+** (`winget install Microsoft.PowerShell`)

---

## License

MIT — see [LICENSE](LICENSE)

---

*Author: [Mikhail Deynekin](https://github.com/paulmann)*
