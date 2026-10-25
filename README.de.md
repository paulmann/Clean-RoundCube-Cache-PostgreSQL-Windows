# Clean RoundCube Cache — PostgreSQL / Windows

<!-- md-i18n:switcher -->
**In anderen Sprachen:** [English](README.md) · Deutsch · [中文](README.zh.md) · [हिन्दी](README.hi.md) · [Español](README.es.md) · [Русский](README.ru.md)

> PowerShell 7.5- und BAT-Skripte zum **TRUNCATE aller Roundcube-Cache-Tabellen** in PostgreSQL unter Windows.  
> `psql.exe` wird **automatisch** gefunden — keine fest codierten Pfade erforderlich.

## Dateien

| Datei | Laufzeit | Zeilen |
|------|---------|-------|
| `Clean_RoundCube_Cache.ps1` | PowerShell 7.5+ | ~206 |
| `Clean_RoundCube_Cache.bat` | cmd.exe (jedes Windows) | ~201 |

---

## Funktionsvergleich

| Funktion | `.ps1` (PowerShell 7.5) | `.bat` (cmd.exe) |
|---------|------------------------|------------------|
| Laufzeitvoraussetzung | PowerShell 7.5+ | Jedes Windows-cmd.exe |
| Farbige Ausgabe | Ja (Cyan / Grün / Rot / Gelb) | Präfix-Tags: `[OK]` / `[FAIL]` / `[WARN]` |
| Typisierte Parameter (`-PgHost`, `-PgUser` …) | Ja, vollständiges `[CmdletBinding]` | Nein (Variablen am Dateianfang bearbeiten) |
| `-NoConfirm`-Stillmodus | Ja (`-NoConfirm`-Schalter) | Nein (fragt immer nach) |
| Passwort vorab per Umgebungsvariable | `$env:PGPASSWORD` | `set PGPASSWORD=` vor dem Start |
| Passworteingabe | `Read-Host -AsSecureString` (maskiert) | `set /p` (in der Konsole sichtbar) |
| Passwort nach dem Lauf gelöscht | Ja (`$env:PGPASSWORD = $null`) | Ja (`set PGPASSWORD=`) |
| Automatische psql.exe-Erkennung | 5-stufige Kette (siehe unten) | 4-stufige Kette (siehe unten) |
| SQL-Übergabe an psql | Inline-Argument `-c` | Temporäre `.sql`-Datei in `%TEMP%` |
| Atomarität | Ein einzelner PL/pgSQL-`DO $$`-Block | Ein einzelner PL/pgSQL-`DO $$`-Block |
| Prüfung der Tabellenexistenz | Ja (`information_schema.tables`) | Ja (`information_schema.tables`) |
| `RESTART IDENTITY CASCADE` | Ja | Ja |
| Bereinigte Tabellen | 5 (siehe Liste unten) | 5 (siehe Liste unten) |
| `ON_ERROR_STOP=1` | Ja | Ja |
| Weitergabe des Exit-Codes | Ja (`exit $exit`) | Ja (`exit /b %EXIT_CODE%`) |
| Bereinigung temporärer Dateien | N/A | Ja (`del /f /q`) |
| Absicherung durch `#Requires -Version 7.5` | Ja | N/A |

---

## Bereinigte Cache-Tabellen

```
cache
cache_index
cache_thread
cache_messages
cache_shared
```

Es werden nur Tabellen verarbeitet, die **tatsächlich** in Ihrer Datenbank vorhanden sind — sicher mit jeder Roundcube-Version.

---

## Automatische psql.exe-Erkennung

Beide Skripte suchen `psql.exe` in der folgenden Reihenfolge und stoppen beim ersten Treffer:

### PowerShell (.ps1) — 5 Schritte

1. **Expliziter Parameter** `-PsqlPath "C:\...\psql.exe"`
2. **System-PATH** — `Get-Command psql.exe`
3. **Umgebungsvariablen** (Bereich Maschine, dann Benutzer):  
   `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME` — geprüft werden sowohl `<var>\psql.exe` als auch `<var>\bin\psql.exe`
4. **Windows-Registrierung** `HKLM\SOFTWARE\PostgreSQL\Installations\*`  
   liest den Wert `Base`, sortiert die Schlüssel nach Version **absteigend**, probiert die neueste zuerst
5. **Dateisystemsuche** in gängigen Wurzelverzeichnissen, Unterordner nach `LastWriteTime` **absteigend** sortiert (die neueste PostgreSQL-Installation gewinnt):
   - `%ProgramFiles%\PostgreSQL`
   - `%ProgramFiles(x86)%\PostgreSQL`
   - `C:\PostgreSQL`, `D:\PostgreSQL`, `E:\PostgreSQL`
   - `C:\pgsql`, `D:\pgsql`

### BAT (.bat) — 4 Schritte

1. **System-PATH** — `for %%I in (psql.exe)`
2. **Umgebungsvariablen** über `reg query` (Maschine, dann Benutzer):  
   `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME`
3. **Windows-Registrierung** `HKLM\SOFTWARE\PostgreSQL\Installations\*` — der neueste Schlüsselname gewinnt
4. **Dateisystemsuche** mit `dir /B /OD /AD` (standardmäßig vom ältesten zum neuesten, letzter Treffer = neuester)  
   Gleiche Wurzelverzeichnisliste wie im PS1

---

## Verwendung

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

## Voraussetzungen

- Windows 10 / Server 2016 oder neuer
- PostgreSQL-Clientwerkzeuge (`psql.exe`) installiert
- Netzwerkzugriff auf den PostgreSQL-Server
- Für `.ps1`: **PowerShell 7.5+** (`winget install Microsoft.PowerShell`)

---

## Lizenz

PolyForm Noncommercial 1.0.0 — siehe [LICENSE](LICENSE)

---

*Autor: [Mikhail Deynekin](https://github.com/paulmann)*
