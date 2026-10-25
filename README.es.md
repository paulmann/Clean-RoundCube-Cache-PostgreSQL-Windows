# Clean RoundCube Cache — PostgreSQL / Windows

<!-- md-i18n:switcher -->
**En otros idiomas:** [English](README.md) · [Deutsch](README.de.md) · [中文](README.zh.md) · [हिन्दी](README.hi.md) · Español · [Русский](README.ru.md)

> Scripts de PowerShell 7.5 y BAT para **TRUNCAR todas las tablas de caché de Roundcube** en PostgreSQL sobre Windows.  
> `psql.exe` se localiza **automáticamente** — no hacen falta rutas fijas.

## Archivos

| Archivo | Entorno de ejecución | Líneas |
|------|---------|-------|
| `Clean_RoundCube_Cache.ps1` | PowerShell 7.5+ | ~206 |
| `Clean_RoundCube_Cache.bat` | cmd.exe (cualquier Windows) | ~201 |

---

## Comparación de funciones

| Función | `.ps1` (PowerShell 7.5) | `.bat` (cmd.exe) |
|---------|------------------------|------------------|
| Requisito de entorno | PowerShell 7.5+ | Cualquier cmd.exe de Windows |
| Salida con colores | Sí (cian / verde / rojo / amarillo) | Etiquetas de prefijo: `[OK]` / `[FAIL]` / `[WARN]` |
| Parámetros tipados (`-PgHost`, `-PgUser` …) | Sí, `[CmdletBinding]` completo | No (se editan las variables al inicio del archivo) |
| Modo silencioso `-NoConfirm` | Sí (conmutador `-NoConfirm`) | No (siempre pregunta) |
| Contraseña predefinida por variable de entorno | `$env:PGPASSWORD` | `set PGPASSWORD=` antes de ejecutar |
| Entrada de contraseña | `Read-Host -AsSecureString` (enmascarada) | `set /p` (visible en la consola) |
| Contraseña borrada tras la ejecución | Sí (`$env:PGPASSWORD = $null`) | Sí (`set PGPASSWORD=`) |
| Detección automática de psql.exe | Cadena de 5 pasos (ver más abajo) | Cadena de 4 pasos (ver más abajo) |
| Entrega del SQL a psql | Argumento `-c` en línea | Archivo `.sql` temporal en `%TEMP%` |
| Atomicidad | Un único bloque PL/pgSQL `DO $$` | Un único bloque PL/pgSQL `DO $$` |
| Comprobación de existencia de las tablas | Sí (`information_schema.tables`) | Sí (`information_schema.tables`) |
| `RESTART IDENTITY CASCADE` | Sí | Sí |
| Tablas limpiadas | 5 (ver la lista más abajo) | 5 (ver la lista más abajo) |
| `ON_ERROR_STOP=1` | Sí | Sí |
| Propagación del código de salida | Sí (`exit $exit`) | Sí (`exit /b %EXIT_CODE%`) |
| Limpieza de archivos temporales | N/A | Sí (`del /f /q`) |
| Guarda `#Requires -Version 7.5` | Sí | N/A |

---

## Tablas de caché limpiadas

```
cache
cache_index
cache_thread
cache_messages
cache_shared
```

Solo se procesan las tablas que **existen realmente** en su base de datos: es seguro con cualquier versión de Roundcube.

---

## Detección automática de psql.exe

Ambos scripts buscan `psql.exe` en el orden siguiente y se detienen en la primera coincidencia:

### PowerShell (.ps1) — 5 pasos

1. **Parámetro explícito** `-PsqlPath "C:\...\psql.exe"`
2. **PATH del sistema** — `Get-Command psql.exe`
3. **Variables de entorno** (ámbito de equipo y luego de usuario):  
   `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME` — comprueba tanto `<var>\psql.exe` como `<var>\bin\psql.exe`
4. **Registro de Windows** `HKLM\SOFTWARE\PostgreSQL\Installations\*`  
   lee el valor `Base`, ordena las claves por versión **de forma descendente** y prueba primero la más reciente
5. **Exploración del sistema de archivos** en los directorios raíz habituales, con las subcarpetas ordenadas por `LastWriteTime` **de forma descendente** (gana la instalación de PostgreSQL más reciente):
   - `%ProgramFiles%\PostgreSQL`
   - `%ProgramFiles(x86)%\PostgreSQL`
   - `C:\PostgreSQL`, `D:\PostgreSQL`, `E:\PostgreSQL`
   - `C:\pgsql`, `D:\pgsql`

### BAT (.bat) — 4 pasos

1. **PATH del sistema** — `for %%I in (psql.exe)`
2. **Variables de entorno** mediante `reg query` (equipo y luego usuario):  
   `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME`
3. **Registro de Windows** `HKLM\SOFTWARE\PostgreSQL\Installations\*` — gana el nombre de clave más reciente
4. **Exploración del sistema de archivos** con `dir /B /OD /AD` (por defecto de la más antigua a la más reciente, la última coincidencia = la más reciente)  
   La misma lista de raíces que en PS1

---

## Uso

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

## Requisitos

- Windows 10 / Server 2016 o posterior
- Herramientas cliente de PostgreSQL (`psql.exe`) instaladas
- Acceso de red al servidor PostgreSQL
- Para `.ps1`: **PowerShell 7.5+** (`winget install Microsoft.PowerShell`)

---

## Licencia

PolyForm Noncommercial 1.0.0 — véase [LICENSE](LICENSE)

---

*Autor: [Mikhail Deynekin](https://github.com/paulmann)*
