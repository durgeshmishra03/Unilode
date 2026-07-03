# Steps to Upgrade Duo Auth Proxy

**By:** Durgesh Mishra
**Classification:** Internal Use Only

---

## Overview
Standard procedure to safely upgrade the Duo Authentication Proxy on a Windows server, including pre-checks, backup, download/verification, and installation.

---

## 1. Pre-Upgrade Checks

Run PowerShell **as Administrator**, then execute:

```powershell
hostname
Get-Date
Get-Service DuoAuthProxy
```

**Expected output:**
```
Status   Name            DisplayName
------   ----            -----------
Running  DuoAuthProxy    Duo Security Authentication Proxy
```

### Check current Duo Proxy version
```powershell
& "C:\Program Files\Duo Security Authentication Proxy\bin\authproxy.exe" --version
```

---

## 2. Create Backup Folders

```powershell
New-Item -ItemType Directory -Path C:\backup -Force
New-Item -ItemType Directory -Path C:\temp -Force
```

---

## 3. Backup Existing Configuration, Logs, and Service Config

```powershell
$date = Get-Date -Format "yyyyMMdd_HHmm"

# Backup conf folder
Copy-Item "C:\Program Files\Duo Security Authentication Proxy\conf" `
    "C:\backup\conf_$date" -Recurse

# Backup log folder
Copy-Item "C:\Program Files\Duo Security Authentication Proxy\log" `
    "C:\backup\log_$date" -Recurse

# Backup service configuration
sc.exe qc DuoAuthProxy > C:\backup\DuoServiceConfig_$date.txt
```

> 💡 Always confirm the backup folders (`conf_<date>`, `log_<date>`) exist and are non-empty before proceeding — this is your rollback point if the upgrade fails.

---

## 4. Download the Latest Installer

```powershell
Invoke-WebRequest -Uri "https://dl.duosecurity.com/duoauthproxy-latest.exe" `
    -OutFile "C:\temp\duoauthproxy-latest.exe"
```

---

## 5. Verify the Installer

### Confirm the file downloaded
```powershell
Get-ChildItem C:\temp\duoauthproxy-latest.exe
```

### Verify the digital signature
```powershell
Get-AuthenticodeSignature "C:\temp\duoauthproxy-latest.exe"
```

**Expected output:**
```
Valid
```

> ⚠️ Do not proceed with installation if the signature status is not `Valid`. This confirms the installer hasn't been tampered with.

---

## 6. Run the Installer

```powershell
C:\temp\duoauthproxy-latest.exe
```

Follow the installer prompts to complete the upgrade.

---

## 7. Post-Upgrade Verification

Re-run the same checks from Step 1 to confirm the service is running and the version has updated:

```powershell
Get-Service DuoAuthProxy
& "C:\Program Files\Duo Security Authentication Proxy\bin\authproxy.exe" --version
```

---

## Quick Reference Checklist

- [ ] Confirmed `DuoAuthProxy` service was running before upgrade
- [ ] Noted current version before upgrade
- [ ] Backup folders created (`C:\backup`, `C:\temp`)
- [ ] Conf, logs, and service config backed up with timestamp
- [ ] Installer downloaded successfully
- [ ] Digital signature verified as `Valid`
- [ ] Installer executed
- [ ] Service confirmed running post-upgrade
- [ ] Version confirmed updated post-upgrade
- [ ] Rollback plan understood (restore from `C:\backup\conf_<date>` / `log_<date>` if needed)
