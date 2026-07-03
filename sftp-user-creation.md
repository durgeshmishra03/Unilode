# SFTP User Management Runbook

Standard procedure for creating, naming, and removing SFTP customer accounts on `AZSEALXINGWPD01`.

---

## 1. Naming Convention

### Username Format
```
<airline_code>sftp
```

**Rules:**
- Use the airline's IATA code + `sftp` (e.g., `cvsftp` for Cargolux)
- Always lowercase (avoids case-sensitivity issues)
- No special characters (`@`, `#`, etc.)

| Airline | IATA Code | Username |
|---|---|---|
| Cargolux | CV | `cvsftp` |
| Gulf Air | GF | `gfsftp` |
| Scandinavian | SK | `sksftp` |

### Password Format
```
<airline_code><2-digit_random_number>_sftp_<random_3-4_char_suffix>
```

**Examples:**
- `cv89_sftp_XkQ`
- `gf57_sftp_P9A`
- `sk22_sftp_ZwL`

---

## 2. Create a New SFTP User

Log into `AZSEALXINGWPD01` via SSH before running these steps.

### Step 1 — Create the user
```bash
sudo adduser USERNAME
```
You'll be prompted to set a password (use the format above).

### Step 2 — Add user to the `sftponly` group
Restricts the account to SFTP-only operations.
```bash
sudo usermod -G sftponly USERNAME
```

### Step 3 — Lock down the home directory
Home directory must be owned by `root` to satisfy SFTP chroot requirements.
```bash
sudo chown root:root /home/USERNAME
```

### Step 4 — Create the uploads directory
Since the home directory is locked, the user gets a writable subdirectory.
```bash
sudo mkdir /home/USERNAME/uploads
```

### Step 5 — Grant ownership of the uploads directory
```bash
sudo chown USERNAME:sftponly /home/USERNAME/uploads
```

### Step 6 — Verify sshd_config (one-time server setup, not per-user)
```bash
sudo vi /etc/ssh/sshd_config
```

Ensure the following exists:
```
Subsystem sftp internal-sftp

Match Group sftpgroup
    ChrootDirectory /home/%u
    ForceCommand internal-sftp
    AllowTCPForwarding no
    X11Forwarding no
```

> ⚠️ Note: Step 2 adds users to `sftponly`, but the `Match Group` block above references `sftpgroup`. Confirm which group name is actually in use on this server and keep it consistent — a mismatch here will silently break the chroot restriction.

Restart sshd after any config change:
```bash
sudo systemctl restart sshd
```

---

## 3. Remove an SFTP User

Accounts must be removed **immediately** once a party is no longer a customer or is excluded from SFTP access. Notify the party after removal.

### Remove user and home directory
```bash
sudo deluser --remove-home USERNAME
```

**On RHEL-based systems** (if `deluser` isn't available):
```bash
sudo userdel -r USERNAME
```

This removes:
- User entry from `/etc/passwd`
- Group entry from `/etc/group`
- Home directory `/home/USERNAME`

### To retain the home directory (e.g., for backup purposes)
Omit the `--remove-home` / `-r` flag:
```bash
sudo deluser USERNAME
```

---

## 4. Quick Reference Checklist

**New account:**
- [ ] Username follows `<airline_code>sftp` format
- [ ] Password follows `<code><##>_sftp_<suffix>` format
- [ ] User added to correct SFTP group
- [ ] Home directory owned by `root:root`
- [ ] `uploads` directory created and owned by `USERNAME:sftponly`
- [ ] Chroot config verified in `sshd_config`
- [ ] Credentials shared securely with customer

**Offboarding:**
- [ ] Confirmed customer/contract has ended
- [ ] Account removed (with or without home directory retained)
- [ ] Customer notified of removal
