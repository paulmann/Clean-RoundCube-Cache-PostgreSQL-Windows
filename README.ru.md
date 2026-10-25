# Clean RoundCube Cache — PostgreSQL / Windows

<!-- md-i18n:switcher -->
**На других языках:** [English](README.md) · [Deutsch](README.de.md) · [中文](README.zh.md) · [हिन्दी](README.hi.md) · [Español](README.es.md) · Русский

> Скрипты PowerShell 7.5 и BAT для **TRUNCATE всех таблиц кеша Roundcube** в PostgreSQL под Windows.  
> `psql.exe` находится **автоматически** — жёстко заданные пути не нужны.

## Файлы

| Файл | Среда выполнения | Строк |
|------|------------------|-------|
| `Clean_RoundCube_Cache.ps1` | PowerShell 7.5+ | ~206 |
| `Clean_RoundCube_Cache.bat` | cmd.exe (любая Windows) | ~201 |

---

## Сравнение возможностей

| Возможность | `.ps1` (PowerShell 7.5) | `.bat` (cmd.exe) |
|-------------|--------------------------|------------------|
| Требование к среде | PowerShell 7.5+ | Любой cmd.exe Windows |
| Цветной вывод | Да (Cyan / Green / Red / Yellow) | Теги-префиксы: `[OK]` / `[FAIL]` / `[WARN]` |
| Типизированные параметры (`-PgHost`, `-PgUser` …) | Да, полный `[CmdletBinding]` | Нет (переменные правятся в начале файла) |
| Беззвучный режим `-NoConfirm` | Да (переключатель `-NoConfirm`) | Нет (спрашивает всегда) |
| Предустановленный пароль через окружение | `$env:PGPASSWORD` | `set PGPASSWORD=` перед запуском |
| Ввод пароля | `Read-Host -AsSecureString` (скрытый) | `set /p` (виден в консоли) |
| Обнуление пароля после запуска | Да (`$env:PGPASSWORD = $null`) | Да (`set PGPASSWORD=`) |
| Автоопределение psql.exe | Цепочка из 5 шагов (см. ниже) | Цепочка из 4 шагов (см. ниже) |
| Передача SQL в psql | Встроенный аргумент `-c` | Временный файл `.sql` в `%TEMP%` |
| Атомарность | Один блок PL/pgSQL `DO $$` | Один блок PL/pgSQL `DO $$` |
| Проверка существования таблиц | Да (`information_schema.tables`) | Да (`information_schema.tables`) |
| `RESTART IDENTITY CASCADE` | Да | Да |
| Очищаемые таблицы | 5 (список ниже) | 5 (список ниже) |
| `ON_ERROR_STOP=1` | Да | Да |
| Передача кода возврата | Да (`exit $exit`) | Да (`exit /b %EXIT_CODE%`) |
| Уборка временных файлов | Н/Д | Да (`del /f /q`) |
| Защита `#Requires -Version 7.5` | Да | Н/Д |

---

## Очищаемые таблицы кеша

```
cache
cache_index
cache_thread
cache_messages
cache_shared
```

Обрабатываются только те таблицы, которые **действительно есть** в вашей базе, — это безопасно для любой версии Roundcube.

---

## Автоопределение psql.exe

Оба скрипта ищут `psql.exe` в следующем порядке и останавливаются на первом совпадении:

### PowerShell (.ps1) — 5 шагов

1. **Явный параметр** `-PsqlPath "C:\...\psql.exe"`
2. **Системный PATH** — `Get-Command psql.exe`
3. **Переменные окружения** (сначала область Machine, затем User):  
   `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME` — проверяются оба варианта: `<var>\psql.exe` и `<var>\bin\psql.exe`
4. **Реестр Windows** `HKLM\SOFTWARE\PostgreSQL\Installations\*`  
   читает значение `Base`, сортирует ключи по версии **по убыванию**, сначала пробует самую новую
5. **Обход файловой системы** по типовым корневым каталогам, подпапки сортируются по `LastWriteTime` **по убыванию** (побеждает самая новая установка PostgreSQL):
   - `%ProgramFiles%\PostgreSQL`
   - `%ProgramFiles(x86)%\PostgreSQL`
   - `C:\PostgreSQL`, `D:\PostgreSQL`, `E:\PostgreSQL`
   - `C:\pgsql`, `D:\pgsql`

### BAT (.bat) — 4 шага

1. **Системный PATH** — `for %%I in (psql.exe)`
2. **Переменные окружения** через `reg query` (сначала Machine, затем User):  
   `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME`
3. **Реестр Windows** `HKLM\SOFTWARE\PostgreSQL\Installations\*` — побеждает имя самого нового ключа
4. **Обход файловой системы** командой `dir /B /OD /AD` (по умолчанию от старых к новым, последнее совпадение = самое новое)  
   Тот же список корней, что и в PS1

---

## Использование

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

## Требования

- Windows 10 / Server 2016 или новее
- Установленные клиентские утилиты PostgreSQL (`psql.exe`)
- Сетевой доступ к серверу PostgreSQL
- Для `.ps1`: **PowerShell 7.5+** (`winget install Microsoft.PowerShell`)

---

## Лицензия

PolyForm Noncommercial 1.0.0 — см. [LICENSE](LICENSE)

---

*Автор: [Mikhail Deynekin](https://github.com/paulmann)*
