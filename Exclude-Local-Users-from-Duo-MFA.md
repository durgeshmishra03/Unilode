# Exclude Local Users from Duo MFA – Configuration Guide

## Objective
This document describes how to allow **local Linux users** to access a VM **without Duo MFA**, while still enforcing **Duo MFA for Active Directory (AD) users**.

## Scope
This applies to Linux VMs that are joined to Active Directory, where Duo MFA is already enabled for SSH login.

## Expected Behavior
| User Type | SSH/SFTP Access | Duo MFA Required? |
|---|---|---|
| AD Users | Yes | ✅ Yes |
| Local Users | Yes | ❌ No |

---

## Before You Start
- You will need **admin/root access** to the VM.
- You will need a terminal (command-line window) connected to the VM.
- Wherever you see `sampleuser`, replace it with the actual username you want to create.
- Wherever you see `samplepassword`, replace it with a strong password of your choice.
- Lines starting with `#` are comments/explanations — you don't need to type those.

---

## Step 1: Create a Local User

Run the following commands one by one in the terminal.

**1. Create the user with a home directory and a bash shell:**
```bash
useradd -m -s /bin/bash sampleuser
```

**2. Set a password for the user** (note: Ubuntu does not support `passwd --stdin`, so we use this method instead):
```bash
echo 'sampleuser:samplepassword' | chpasswd
```
> Replace `samplepassword` with your own secure password.

**3. Add the user to the `sudo` group** (this gives them admin rights):
```bash
usermod -aG sudo sampleuser
```

**4. Allow the user to run admin commands without typing a password each time:**
```bash
echo 'sampleuser ALL=(ALL) NOPASSWD:ALL' | tee /etc/sudoers.d/90-sampleuser
```

**5. Set the correct file permissions** (this keeps the configuration secure):
```bash
chmod 0440 /etc/sudoers.d/90-sampleuser
```

---

## Step 2: Tell the System to Skip Duo MFA for Local Users

This step edits a system file that controls login security rules.

1. Open the file for editing:
   ```
   /etc/pam.d/sshd
   ```

2. Find the line that mentions `pam_duo.so`. **Just above that line**, add this new line:
   ```
   # Skip Duo for all local users (UID < 2000)
   auth [success=1 default=ignore] pam_succeed_if.so uid < 2000
   ```

3. Make sure the Duo line is still present **below** the line you just added:
   ```
   auth required /lib64/security/pam_duo.so
   ```

> **In plain terms:** This tells the system, "If this is a local user (not an AD user), skip the Duo MFA check. If it's an AD user, still ask for Duo MFA."

---

## Step 3: Allow the Local User to Log In via SSH

1. Open the SSH configuration file:
   ```
   /etc/ssh/sshd_config
   ```

2. Find the line that starts with `AllowGroups`. This line lists who is allowed to log in.

   **Recommended approach — use a group instead of listing individual users:**

   a. Create a new group for local SSH users:
      ```bash
      groupadd local-ssh
      ```

   b. Add your user to this group:
      ```bash
      usermod -aG local-ssh sampleuser
      ```

   c. Update the `AllowGroups` line in `sshd_config` to include this group, for example:
      ```
      AllowGroups azureuser ruth sampleuser domain-admins local-ssh
      ```

> This makes sure only approved local users (and AD groups) are allowed to connect over SSH.

---

## Step 4: Restart the SSH Service

This applies all the changes you just made. Run **one** of the following commands (whichever works on your system):

```bash
systemctl restart ssh
```
or
```bash
systemctl restart sshd
```

---

## Step 5: Test Everything (Validation)

Check that everything works as expected:

- ✅ **Log in as the local user** (`sampleuser`) → it should log in directly, **without** asking for Duo MFA.
- ✅ **Log in as an AD user** → it should still **ask for Duo MFA** as normal.
- 🔍 If something isn't working, check the log file for clues:
  ```
  /var/log/auth.log
  ```

---

## Summary
With this setup:
- **AD users** remain protected by Duo MFA, as required.
- **Local users** (such as service or admin accounts) can log in directly without MFA prompts.

This gives a secure, scalable way to manage both types of accounts on the same VM.
