@echo off
:: ==============================================================================
:: Clean_RoundCube_Cache.bat
:: Author  : Mikhail Deynekin | https://github.com/paulmann
:: Version : 2.0.0
:: Requires: psql.exe (PostgreSQL, auto-detected)
:: Purpose : Truncate all Roundcube cache tables in PostgreSQL
:: ------------------------------------------------------------------------------
:: psql.exe detection order:
::   1. Already in PATH
::   2. Env vars: PSQLPATH, PGBIN, PGROOT, PGHOME  (Machine then User)
::   3. Registry: HKLM\SOFTWARE\PostgreSQL\Installations\*  (newest version first)
::   4. Filesystem scan: %ProgramFiles%\PostgreSQL\*\bin\  (newest folder first)
::      then C:\PostgreSQL, D:\PostgreSQL, C:\pgsql, D:\pgsql
:: ==============================================================================

setlocal EnableDelayedExpansion

set PG_HOST=localhost
set PG_PORT=5432
set PG_USER=postgres
set PG_DATABASE=roundcube
set PSQL_EXE=

echo.
echo  === RoundCube Cache Cleaner v2.0 (PostgreSQL / Windows) ===========
echo.

:: ============================================================
:: 1. Search in PATH
:: ============================================================
for %%I in (psql.exe) do (
    if not "%%~$PATH:I"=="" (
        set "PSQL_EXE=%%~$PATH:I"
        echo  [OK]   Found via PATH: !PSQL_EXE!
        goto :psql_found
    )
)

:: ============================================================
:: 2. Environment variables: PSQLPATH, PGBIN, PGROOT, PGHOME
:: ============================================================
for %%V in (PSQLPATH PGBIN PGROOT PGHOME) do (
    set "_ENVVAL="
    :: Machine scope
    for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%%V" 2^>nul') do set "_ENVVAL=%%B"
    :: User scope fallback
    if "!_ENVVAL!"=="" (
        for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v "%%V" 2^>nul') do set "_ENVVAL=%%B"
    )
    if not "!_ENVVAL!"=="" (
        if exist "!_ENVVAL!\psql.exe" (
            set "PSQL_EXE=!_ENVVAL!\psql.exe"
            echo  [OK]   Found via env %%V: !PSQL_EXE!
            goto :psql_found
        )
        if exist "!_ENVVAL!\bin\psql.exe" (
            set "PSQL_EXE=!_ENVVAL!\bin\psql.exe"
            echo  [OK]   Found via env %%V\bin: !PSQL_EXE!
            goto :psql_found
        )
    )
)

:: ============================================================
:: 3. Windows Registry: newest version first
:: ============================================================
set _REG_FOUND=0
set _BEST_VER=0
set _BEST_PATH=

for /f "tokens=*" %%K in ('reg query "HKLM\SOFTWARE\PostgreSQL\Installations" 2^>nul') do (
    for /f "tokens=2*" %%A in ('reg query "%%K" /v "Base" 2^>nul') do (
        set "_BASE=%%B"
        if exist "!_BASE!\bin\psql.exe" (
            :: Extract version number from key name for sorting
            for %%P in ("%%K") do set "_KNAME=%%~nxP"
            if !_KNAME! gtr !_BEST_VER! (
                set "_BEST_VER=!_KNAME!"
                set "_BEST_PATH=!_BASE!\bin\psql.exe"
            )
        )
    )
)
if not "!_BEST_PATH!"=="" (
    set "PSQL_EXE=!_BEST_PATH!"
    echo  [OK]   Found via Registry: !PSQL_EXE!
    goto :psql_found
)

:: ============================================================
:: 4. Filesystem scan - newest subfolder first
:: ============================================================
echo  [....] Scanning filesystem for psql.exe...

set _ROOTS=%ProgramFiles%\PostgreSQL %ProgramFiles(x86)%\PostgreSQL C:\PostgreSQL D:\PostgreSQL E:\PostgreSQL C:\pgsql D:\pgsql

:: Sort by date descending using dir /OD /B, then iterate
for %%R in (%_ROOTS%) do (
    if exist "%%R" (
        for /f "delims=" %%D in ('dir /B /OD /AD "%%R" 2^>nul') do (
            if exist "%%R\%%D\bin\psql.exe" (
                set "PSQL_EXE=%%R\%%D\bin\psql.exe"
                echo  [OK]   Found via filesystem: !PSQL_EXE!
                goto :psql_found
            )
        )
    )
)

:: ============================================================
:: Not found
:: ============================================================
echo  [FAIL] psql.exe not found.
echo         Install PostgreSQL or set PGBIN / PSQLPATH environment variable.
endlocal & pause & exit /b 1

:psql_found

:: ============================================================
:: Confirm
:: ============================================================
echo.
echo  [WARN] DB     : %PG_DATABASE% @ %PG_HOST%:%PG_PORT%  user: %PG_USER%
echo  [WARN] Tables : cache, cache_index, cache_thread, cache_messages, cache_shared
echo.
set /p CONFIRM= Continue? (yes/no): 
if /i not "!CONFIRM!"=="yes" (
    if /i not "!CONFIRM!"=="y" (
        echo  Cancelled.
        endlocal & exit /b 0
    )
)

:: ============================================================
:: Password
:: ============================================================
if "%PGPASSWORD%"=="" (
    set /p PGPASSWORD= PostgreSQL password for '%PG_USER%': 
)

:: ============================================================
:: Build SQL in temp file (avoids $$ quoting hell in cmd.exe)
:: ============================================================
set SQL_FILE=%TEMP%\rc_cache_clean_%RANDOM%.sql

(
echo DO $$
echo DECLARE
echo     t            TEXT;
echo     tables       TEXT[] := ARRAY['cache','cache_index','cache_thread',
echo                                   'cache_messages','cache_shared'];
echo     found_tables TEXT[] := '{}';
echo     stmt         TEXT;
echo BEGIN
echo     FOREACH t IN ARRAY tables LOOP
echo         IF EXISTS (
echo             SELECT 1 FROM information_schema.tables
echo             WHERE  table_schema = 'public' AND table_name = t
echo         ^) THEN
echo             found_tables := array_append(found_tables, t^);
echo         END IF;
echo     END LOOP;
echo     IF array_length(found_tables, 1^) IS NULL THEN
echo         RAISE NOTICE 'No Roundcube cache tables found -- nothing to do.';
echo         RETURN;
echo     END IF;
echo     FOREACH t IN ARRAY found_tables LOOP
echo         stmt := format('TRUNCATE TABLE public.%%I RESTART IDENTITY CASCADE', t^);
echo         EXECUTE stmt;
echo         RAISE NOTICE 'TRUNCATED: %%', t;
echo     END LOOP;
echo     RAISE NOTICE 'Done. %% table(s) cleaned.', array_length(found_tables, 1^);
echo END;
echo $$;
) > "%SQL_FILE%"

:: ============================================================
:: Execute
:: ============================================================
echo.
echo  [....] Connecting and running TRUNCATE...

"%PSQL_EXE%" -h %PG_HOST% -p %PG_PORT% -U %PG_USER% -d %PG_DATABASE% -v ON_ERROR_STOP=1 -f "%SQL_FILE%"
set EXIT_CODE=%ERRORLEVEL%

:: ============================================================
:: Cleanup
:: ============================================================
del /f /q "%SQL_FILE%" 2>nul
set PGPASSWORD=

echo.
if %EXIT_CODE% neq 0 (
    echo  [FAIL] Error, psql exit code: %EXIT_CODE%
    endlocal & pause & exit /b %EXIT_CODE%
)
echo  [OK]   Roundcube cache cleaned successfully.
echo.
endlocal
pause
