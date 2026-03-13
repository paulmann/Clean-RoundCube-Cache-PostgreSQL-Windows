# ==============================================================================
# Clean_RoundCube_Cache.ps1
# Author  : Mikhail Deynekin | https://github.com/paulmann
# Version : 2.0.0
# Requires: PowerShell 7.5+, PostgreSQL psql.exe (auto-detected)
# Purpose : Truncate all Roundcube cache tables in PostgreSQL
# ------------------------------------------------------------------------------
# psql.exe detection order:
#   1. Explicit -PsqlPath parameter
#   2. System / User PATH
#   3. Env vars: PSQLPATH, PGBIN, PGROOT, PGHOME
#   4. Windows Registry: HKLM\SOFTWARE\PostgreSQL\Installations\*
#   5. Filesystem scan under common roots, sorted by LastWriteTime DESC
# ==============================================================================

#Requires -Version 7.5

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $PgHost     = "localhost",
    [int]    $PgPort     = 5432,
    [string] $PgUser     = "postgres",
    [string] $PgDatabase = "roundcube",
    [string] $PsqlPath   = "",   # Leave empty for auto-detection
    [switch] $NoConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Console helpers ──────────────────────────────────────────────────────────
function Write-Step  ([string]$m) { Write-Host "  >> $m" -ForegroundColor Cyan    }
function Write-Ok    ([string]$m) { Write-Host "  OK $m" -ForegroundColor Green   }
function Write-Fail  ([string]$m) { Write-Host " ERR $m" -ForegroundColor Red     }
function Write-Warn  ([string]$m) { Write-Host "   ! $m" -ForegroundColor Yellow  }
function Write-Banner([string]$m) { Write-Host "`n$m`n"  -ForegroundColor Magenta }

# ─── Smart psql.exe resolver ──────────────────────────────────────────────────
function Find-Psql {
    # 1. Explicit parameter
    if ($PsqlPath -and (Test-Path $PsqlPath)) {
        Write-Step "Using explicitly provided path."
        return $PsqlPath
    }

    # 2. Already in PATH
    $fromPath = Get-Command psql.exe -ErrorAction SilentlyContinue
    if ($fromPath) {
        Write-Step "Found via PATH."
        return $fromPath.Source
    }

    # 3. Environment variables: PSQLPATH, PGBIN, PGROOT, PGHOME
    foreach ($envVar in @("PSQLPATH", "PGBIN", "PGROOT", "PGHOME")) {
        $val = [Environment]::GetEnvironmentVariable($envVar, "Machine")
        if (-not $val) { $val = [Environment]::GetEnvironmentVariable($envVar, "User") }
        if ($val) {
            foreach ($suffix in @("", "bin")) {
                $candidate = if ($suffix) { Join-Path $val "$suffix\psql.exe" } else { Join-Path $val "psql.exe" }
                if (Test-Path $candidate) {
                    Write-Step "Found via env var $envVar."
                    return $candidate
                }
            }
        }
    }

    # 4. Windows Registry: HKLM\SOFTWARE\PostgreSQL\Installations\*
    $regBases = @(
        "HKLM:\SOFTWARE\PostgreSQL\Installations",
        "HKLM:\SOFTWARE\WOW6432Node\PostgreSQL\Installations"
    )
    foreach ($regBase in $regBases) {
        if (-not (Test-Path $regBase)) { continue }
        $keys = Get-ChildItem $regBase -ErrorAction SilentlyContinue |
                Sort-Object {
                    $ver = ($_.PSChildName -replace '[^0-9.]', '') -replace '^\.',  '0.'
                    try { [version]$ver } catch { [version]"0.0" }
                } -Descending
        foreach ($key in $keys) {
            $base = (Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue).Base
            if ($base) {
                $candidate = Join-Path $base "bin\psql.exe"
                if (Test-Path $candidate) {
                    Write-Step "Found via Registry ($($key.PSChildName))."
                    return $candidate
                }
            }
        }
    }

    # 5. Filesystem scan — common root dirs, sub-folders sorted by LastWriteTime DESC
    $rootDirs = @(
        "$env:ProgramFiles\PostgreSQL",
        "${env:ProgramFiles(x86)}\PostgreSQL",
        "$env:ProgramW6432\PostgreSQL",
        "C:\PostgreSQL",
        "D:\PostgreSQL",
        "E:\PostgreSQL",
        "C:\pgsql",
        "D:\pgsql"
    )
    foreach ($root in $rootDirs) {
        if (-not (Test-Path $root -PathType Container)) { continue }
        $subDirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending
        foreach ($dir in $subDirs) {
            $candidate = Join-Path $dir.FullName "bin\psql.exe"
            if (Test-Path $candidate) {
                Write-Step "Found via filesystem scan ($($dir.FullName))."
                return $candidate
            }
        }
    }

    return $null
}

# ─── PL/pgSQL block — safe TRUNCATE with existence check ──────────────────────
$SQL = @"
DO `$`$
DECLARE
    t            TEXT;
    tables       TEXT[] := ARRAY['cache','cache_index','cache_thread',
                                  'cache_messages','cache_shared'];
    found_tables TEXT[] := '{}';
    stmt         TEXT;
BEGIN
    FOREACH t IN ARRAY tables LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE  table_schema = 'public' AND table_name = t
        ) THEN
            found_tables := array_append(found_tables, t);
        END IF;
    END LOOP;
    IF array_length(found_tables, 1) IS NULL THEN
        RAISE NOTICE 'No Roundcube cache tables found -- nothing to do.';
        RETURN;
    END IF;
    FOREACH t IN ARRAY found_tables LOOP
        stmt := format('TRUNCATE TABLE public.%I RESTART IDENTITY CASCADE', t);
        EXECUTE stmt;
        RAISE NOTICE 'TRUNCATED: %', t;
    END LOOP;
    RAISE NOTICE 'Done. % table(s) cleaned.', array_length(found_tables, 1);
END;
`$`$;
"@

# ══════════════════════════════════════════════════════════════════════════════
Write-Banner "=== RoundCube Cache Cleaner v2.0 (PostgreSQL / Windows) =========="

# ─── Resolve psql.exe ─────────────────────────────────────────────────────────
Write-Step "Searching for psql.exe..."
$resolvedPsql = Find-Psql
if (-not $resolvedPsql) {
    Write-Fail "psql.exe not found. Install PostgreSQL or set PGBIN / PSQLPATH environment variable."
    exit 1
}
Write-Ok "psql.exe -> $resolvedPsql"

# ─── Confirm ──────────────────────────────────────────────────────────────────
if (-not $NoConfirm) {
    Write-Warn "Target : $PgDatabase @ $PgHost`:$PgPort  (user: $PgUser)"
    Write-Warn "Tables : cache, cache_index, cache_thread, cache_messages, cache_shared"
    $ans = Read-Host "`n  Proceed? (yes/no)"
    if ($ans -notin @("yes", "y")) { Write-Warn "Cancelled by user."; exit 0 }
}

# ─── Password (never exposed in process list) ─────────────────────────────────
if (-not $env:PGPASSWORD) {
    $sec            = Read-Host "  PostgreSQL password for '$PgUser'" -AsSecureString
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                          [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}

# ─── Execute ──────────────────────────────────────────────────────────────────
Write-Step "Connecting and running TRUNCATE..."

$psqlArgs = @(
    "-h", $PgHost,
    "-p", $PgPort,
    "-U", $PgUser,
    "-d", $PgDatabase,
    "-v", "ON_ERROR_STOP=1",
    "-c", $SQL
)
$output = & $resolvedPsql @psqlArgs 2>&1
$exit   = $LASTEXITCODE

$output | ForEach-Object {
    $line = $_.ToString()
    switch -Regex ($line) {
        "NOTICE.*(TRUNCATED|Done)" { Write-Ok   $line; break }
        "ERROR|FATAL|PANIC"        { Write-Fail $line; break }
        default                    { Write-Host "     $line" -ForegroundColor Gray }
    }
}

# ─── Cleanup sensitive data ───────────────────────────────────────────────────
$env:PGPASSWORD = $null

if ($exit -ne 0) { Write-Fail "psql exited with code $exit."; exit $exit }
Write-Ok "Roundcube cache cleaned successfully."
Write-Host ""
