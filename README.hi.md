# Clean RoundCube Cache — PostgreSQL / Windows

<!-- md-i18n:switcher -->
**अन्य भाषाओं में:** [English](README.md) · [Deutsch](README.de.md) · [中文](README.zh.md) · हिन्दी · [Español](README.es.md) · [Русский](README.ru.md)

> Windows पर PostgreSQL में **Roundcube की सभी cache तालिकाओं को TRUNCATE** करने के लिए PowerShell 7.5 और BAT स्क्रिप्ट।  
> `psql.exe` **स्वतः** मिल जाता है — कोई हार्डकोडेड पथ आवश्यक नहीं।

## फ़ाइलें

| फ़ाइल | रनटाइम | पंक्तियाँ |
|------|---------|-------|
| `Clean_RoundCube_Cache.ps1` | PowerShell 7.5+ | ~206 |
| `Clean_RoundCube_Cache.bat` | cmd.exe (कोई भी Windows) | ~201 |

---

## सुविधाओं की तुलना

| सुविधा | `.ps1` (PowerShell 7.5) | `.bat` (cmd.exe) |
|---------|------------------------|------------------|
| रनटाइम आवश्यकता | PowerShell 7.5+ | कोई भी Windows cmd.exe |
| रंग-कोडित आउटपुट | हाँ (Cyan / Green / Red / Yellow) | उपसर्ग टैग: `[OK]` / `[FAIL]` / `[WARN]` |
| टाइप किए गए पैरामीटर (`-PgHost`, `-PgUser` …) | हाँ, पूरा `[CmdletBinding]` | नहीं (फ़ाइल के ऊपर वेरिएबल संपादित करें) |
| `-NoConfirm` साइलेंट मोड | हाँ (`-NoConfirm` स्विच) | नहीं (हमेशा पूछता है) |
| env के माध्यम से पहले से सेट पासवर्ड | `$env:PGPASSWORD` | `set PGPASSWORD=` before run |
| पासवर्ड इनपुट | `Read-Host -AsSecureString` (मास्क किया गया) | `set /p` (कंसोल में दिखता है) |
| रन के बाद पासवर्ड शून्य | Yes (`$env:PGPASSWORD = $null`) | Yes (`set PGPASSWORD=`) |
| psql.exe की स्वतः पहचान | 5-चरणीय श्रृंखला (नीचे देखें) | 4-चरणीय श्रृंखला (नीचे देखें) |
| psql को SQL की आपूर्ति | इनलाइन `-c` आर्ग्युमेंट | `%TEMP%` में अस्थायी `.sql` फ़ाइल |
| Atomicity | एकल PL/pgSQL `DO $$` ब्लॉक | एकल PL/pgSQL `DO $$` ब्लॉक |
| तालिका के अस्तित्व की जाँच | हाँ (`information_schema.tables`) | हाँ (`information_schema.tables`) |
| `RESTART IDENTITY CASCADE` | हाँ | हाँ |
| साफ़ की गई तालिकाएँ | 5 (सूची नीचे देखें) | 5 (सूची नीचे देखें) |
| `ON_ERROR_STOP=1` | हाँ | हाँ |
| एग्ज़िट कोड का प्रसार | हाँ (`exit $exit`) | हाँ (`exit /b %EXIT_CODE%`) |
| अस्थायी फ़ाइल की सफ़ाई | लागू नहीं | हाँ (`del /f /q`) |
| `#Requires -Version 7.5` गार्ड | हाँ | लागू नहीं |

---

## साफ़ की जाने वाली cache तालिकाएँ

```
cache
cache_index
cache_thread
cache_messages
cache_shared
```

आपके DB में **वास्तव में मौजूद** तालिकाएँ ही संसाधित होती हैं — Roundcube के किसी भी संस्करण पर सुरक्षित।

---

## psql.exe की स्वतः पहचान

दोनों स्क्रिप्ट `psql.exe` को निम्न क्रम में खोजती हैं और पहले मिलने पर रुक जाती हैं:

### PowerShell (.ps1) — 5 चरण

1. **स्पष्ट पैरामीटर** `-PsqlPath "C:\...\psql.exe"`
2. **System PATH** — `Get-Command psql.exe`
3. **एनवायरनमेंट वेरिएबल** (पहले Machine, फिर User स्कोप):  
   `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME` — `<var>\psql.exe` और `<var>\bin\psql.exe` दोनों की जाँच करता है
4. **Windows रजिस्ट्री** `HKLM\SOFTWARE\PostgreSQL\Installations\*`  
   `Base` मान पढ़ता है, कुंजियों को संस्करण के अनुसार **अवरोही** क्रम में लगाता है, सबसे नए से शुरू करता है
5. **फ़ाइल सिस्टम स्कैन** — सामान्य रूट निर्देशिकाओं में, उप-फ़ोल्डर `LastWriteTime` के अनुसार **अवरोही** क्रम में (सबसे नया PostgreSQL इंस्टॉल जीतता है):
   - `%ProgramFiles%\PostgreSQL`
   - `%ProgramFiles(x86)%\PostgreSQL`
   - `C:\PostgreSQL`, `D:\PostgreSQL`, `E:\PostgreSQL`
   - `C:\pgsql`, `D:\pgsql`

### BAT (.bat) — 4 चरण

1. **System PATH** — `for %%I in (psql.exe)`
2. **एनवायरनमेंट वेरिएबल** `reg query` के माध्यम से (पहले Machine, फिर User):  
   `PSQLPATH`, `PGBIN`, `PGROOT`, `PGHOME`
3. **Windows रजिस्ट्री** `HKLM\SOFTWARE\PostgreSQL\Installations\*` — सबसे नया कुंजी-नाम जीतता है
4. **फ़ाइल सिस्टम स्कैन** `dir /B /OD /AD` का उपयोग करके (डिफ़ॉल्ट रूप से पुराने से नए की ओर, अंतिम मिलान = सबसे नया)  
   PS1 जैसी ही रूट सूची

---

## उपयोग

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

## आवश्यकताएँ

- Windows 10 / Server 2016 या नया
- PostgreSQL क्लाइंट टूल्स (`psql.exe`) इंस्टॉल होना आवश्यक
- PostgreSQL सर्वर तक नेटवर्क पहुँच
- `.ps1` के लिए: **PowerShell 7.5+** (`winget install Microsoft.PowerShell`)

---

## लाइसेंस

PolyForm Noncommercial 1.0.0 — [LICENSE](LICENSE) देखें

---

*लेखक: [Mikhail Deynekin](https://github.com/paulmann)*
