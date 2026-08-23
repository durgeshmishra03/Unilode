# SFTP Public Key Login Setup (Production)

Sets up public-key authentication for a client's existing SFTP account. Assumes the user account, its home directory, and base permissions are already created/configured by your other provisioning script.

## Placeholder — replace before running

| Placeholder | Replace with |
|---|---|
| `<CLIENT_USER>` | Production SFTP username for this client |

> Search this file for `<CLIENT_USER>` and replace all occurrences with the actual account name before running.

---

## Step 1 — Create the `.ssh` directory

```bash
sudo mkdir -p /home/<CLIENT_USER>/.ssh
```
> Creates the `.ssh` directory inside the user's home, where their public key will live.

## Step 2 — Lock down `.ssh` directory permissions

```bash
sudo chmod 700 /home/<CLIENT_USER>/.ssh
```
> Restricts the `.ssh` folder so only its owning user can access it — SSH will refuse to use keys if this is too open.

## Step 3 — Paste the client's public key here

```bash
sudo nano /home/<CLIENT_USER>/.ssh/authorized_keys
```
> Opens (and creates, if missing) the `authorized_keys` file — **this is where you paste the client's SSH public key** (the `.pub` file content, one key per line, e.g. `ssh-ed25519 AAAA... client@laptop`). Only the public key ever goes on the server — never the private key.

## Step 4 — Lock down `authorized_keys` file permissions

```bash
sudo chmod 600 /home/<CLIENT_USER>/.ssh/authorized_keys
```
> Restricts the key file to read/write for the owner only — SSH silently ignores `authorized_keys` if it's group- or world-writable.

## Step 5 — Fix ownership of `.ssh`

```bash
sudo chown -R <CLIENT_USER>:<CLIENT_USER> /home/<CLIENT_USER>/.ssh
```
> Hands ownership of the `.ssh` folder and its contents to the user, so SSH will trust and use it.

---

## Step 6 — Test the login

```bash
sftp -i /path/to/client_private_key <CLIENT_USER>@<SERVER_IP_OR_HOST>
```
> Confirms the client can authenticate using their private key against the public key you just installed.

---

## Quick checklist

- [ ] Replaced `<CLIENT_USER>` everywhere
- [ ] Client's **public** key (not private) pasted into `authorized_keys`
- [ ] `.ssh` is `700`, `authorized_keys` is `600`, both owned by `<CLIENT_USER>`
- [ ] Test login succeeds with the client's private key
