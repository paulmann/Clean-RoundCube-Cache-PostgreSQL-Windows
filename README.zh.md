# Clean RoundCube Cache — PostgreSQL / Windows

<!-- md-i18n:switcher -->
**其他语言：** [English](README.md) · [Deutsch](README.de.md) · 中文 · [हिन्दी](README.hi.md) · [Español](README.es.md) · [Русский](README.ru.md)

> 在 Windows 上的 PostgreSQL 中用 PowerShell 7.5 和 BAT 脚本**清空（TRUNCATE）Roundcube 的全部缓存表**。  
> `psql.exe` 会被**自动定位**——无需硬编码路径。

## 文件

| 文件 | 运行环境 | 行数 |
|------|---------|-------|
| `Clean_RoundCube_Cache.ps1` | PowerShell 7.5+ | ~206 |
| `Clean_RoundCube_Cache.bat` | cmd.exe（任意 Windows） | ~201 |

---

## 功能对比

| 功能 | `.ps1`（PowerShell 7.5） | `.bat`（cmd.exe） |
|---------|------------------------|------------------|
| 运行环境要求 | PowerShell 7.5+ | 任意 Windows cmd.exe |
| 彩色输出 | 是（青色 / 绿色 / 红色 / 黄色） | 前缀标签：`[OK]` / `[FAIL]` / `[WARN]` |
| 类型化参数（`-PgHost`、`-PgUser` …） | 是，完整的 `[CmdletBinding]` | 否（在文件顶部修改变量） |
| `-NoConfirm` 静默模式 | 是（`-NoConfirm` 开关） | 否（总是询问） |
| 通过环境变量预设密码 | `$env:PGPASSWORD` | 运行前 `set PGPASSWORD=` |
| 密码输入 | `Read-Host -AsSecureString`（掩码） | `set /p`（在控制台中可见） |
| 运行后清零密码 | 是（`$env:PGPASSWORD = $null`） | 是（`set PGPASSWORD=`） |
| psql.exe 自动检测 | 5 步查找链（见下文） | 4 步查找链（见下文） |
| 向 psql 传递 SQL | 内联 `-c` 参数 | `%TEMP%` 中的临时 `.sql` 文件 |
| 原子性 | 单个 PL/pgSQL `DO $$` 块 | 单个 PL/pgSQL `DO $$` 块 |
| 表存在性检查 | 是（`information_schema.tables`） | 是（`information_schema.tables`） |
| `RESTART IDENTITY CASCADE` | 是 | 是 |
| 清理的表数量 | 5（见下方列表） | 5（见下方列表） |
| `ON_ERROR_STOP=1` | 是 | 是 |
| 退出码传递 | 是（`exit $exit`） | 是（`exit /b %EXIT_CODE%`） |
| 临时文件清理 | N/A | 是（`del /f /q`） |
| `#Requires -Version 7.5` 守卫 | 是 | N/A |

---

## 清理的缓存表

```
cache
cache_index
cache_thread
cache_messages
cache_shared
```

只处理数据库中**确实存在**的表——因此对任何 Roundcube 版本都安全。

---

## psql.exe 自动检测

两个脚本都按以下顺序查找 `psql.exe`，命中第一个即停止：

### PowerShell（.ps1）——5 个步骤

1. **显式参数** `-PsqlPath "C:\...\psql.exe"`
2. **系统 PATH** — `Get-Command psql.exe`
3. **环境变量**（先 Machine，再 User 作用域）：  
   `PSQLPATH`、`PGBIN`、`PGROOT`、`PGHOME` — 同时检查 `<var>\psql.exe` 与 `<var>\bin\psql.exe`
4. **Windows 注册表** `HKLM\SOFTWARE\PostgreSQL\Installations\*`  
   读取 `Base` 值，按版本**降序**排列键，优先尝试最新的安装
5. **文件系统扫描**常见根目录，子目录按 `LastWriteTime` **降序**排列（最新的 PostgreSQL 安装优先）：
   - `%ProgramFiles%\PostgreSQL`
   - `%ProgramFiles(x86)%\PostgreSQL`
   - `C:\PostgreSQL`、`D:\PostgreSQL`、`E:\PostgreSQL`
   - `C:\pgsql`、`D:\pgsql`

### BAT（.bat）——4 个步骤

1. **系统 PATH** — `for %%I in (psql.exe)`
2. **环境变量**，通过 `reg query`（先 Machine，再 User）：  
   `PSQLPATH`、`PGBIN`、`PGROOT`、`PGHOME`
3. **Windows 注册表** `HKLM\SOFTWARE\PostgreSQL\Installations\*` — 键名最新的胜出
4. **文件系统扫描**，使用 `dir /B /OD /AD`（默认由旧到新，最后一个匹配即最新）  
   根目录列表与 PS1 相同

---

## 用法

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

## 系统要求

- Windows 10 / Server 2016 或更高版本
- 已安装 PostgreSQL 客户端工具（`psql.exe`）
- 可访问 PostgreSQL 服务器的网络
- 对于 `.ps1`：**PowerShell 7.5+**（`winget install Microsoft.PowerShell`）

---

## 许可证

PolyForm Noncommercial 1.0.0 — 参见 [LICENSE](LICENSE)

---

*作者：[Mikhail Deynekin](https://github.com/paulmann)*
