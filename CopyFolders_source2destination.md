# Copy a Folder Between Two Private-IP VMs (via your local/bastion machine)

**Scenario:** Source VM and Destination VM both have private IPs and can't reach
each other directly. But your local machine (or a bastion host) can reach both
— so we pull the folder down locally first, then push it up to the destination.

Replace the placeholders before running:
- `SRC_USER` / `SRC_HOST` / `SRC_PATH` — source VM login + folder path
- `DEST_USER` / `DEST_HOST` / `DEST_PATH` — destination VM login + folder path
- `LOCAL_TMP` — a temporary folder on your local machine to stage the copy

---

## Step 1 — Test access to the source VM

```bash
ssh SRC_USER@SRC_HOST "echo connected"
```
> Confirms you can log into the source VM before starting anything else.

---

## Step 2 — Test access to the destination VM

```bash
ssh DEST_USER@DEST_HOST "echo connected"
```
> Confirms you can log into the destination VM before starting anything else.

---

## Step 3 — Check the folder size on the source (optional but useful)

```bash
ssh SRC_USER@SRC_HOST "du -sh SRC_PATH"
```
> Shows how big the folder is, so you know what to expect for transfer time and local disk space.

---

## Step 4 — Download the folder from source VM to your local machine

```bash
scp -r SRC_USER@SRC_HOST:SRC_PATH LOCAL_TMP
```
> Recursively copies the entire folder from the source VM down to your local machine.

**Faster alternative for large folders (compressed, single stream, no intermediate files on the source):**
```bash
ssh SRC_USER@SRC_HOST "tar czf - -C \$(dirname SRC_PATH) \$(basename SRC_PATH)" > local_folder.tar.gz
```
> Streams a compressed tarball of the folder straight to your local machine over SSH.

---

## Step 5 — Verify the local copy

```bash
ls -la LOCAL_TMP
```
> Confirms the folder actually downloaded and lists what's inside it.

```bash
du -sh LOCAL_TMP
```
> Compares the downloaded size against what you saw on the source in Step 3.

---

## Step 6 — Upload the folder from your local machine to the destination VM

```bash
scp -r LOCAL_TMP DEST_USER@DEST_HOST:DEST_PATH
```
> Recursively copies the folder from your local machine up to the destination VM.

**Faster alternative for large folders (extracts the tarball directly on the destination):**
```bash
cat local_folder.tar.gz | ssh DEST_USER@DEST_HOST "tar xzf - -C DEST_PATH"
```
> Streams and extracts the compressed tarball directly on the destination without leaving a .tar.gz file behind there.

> **If DEST_PATH needs root to write to** (e.g. under `/etc`): upload to a temp folder you *do* have permission for, then move it into place with sudo:
> ```bash
> scp -r LOCAL_TMP DEST_USER@DEST_HOST:/tmp/incoming_folder
> ssh DEST_USER@DEST_HOST "sudo mv /tmp/incoming_folder DEST_PATH"
> ```
> Uploads to a location you can write to, then uses sudo on the destination to move it into the protected path.

---

## Step 7 — Verify the folder landed on the destination

```bash
ssh DEST_USER@DEST_HOST "ls -la DEST_PATH"
```
> Confirms the folder and its contents are present on the destination VM.

```bash
ssh DEST_USER@DEST_HOST "du -sh DEST_PATH"
```
> Confirms the size on the destination matches the source (Step 3) and local copy (Step 5).

---

## Step 8 — (Optional) Integrity check with checksums

```bash
find LOCAL_TMP -type f -exec md5sum {} \; | awk '{print $1}' | sort | md5sum
```
> Produces one combined checksum for every file in your local copy, so you can compare it against the same command run on the source and destination folders — if all three match, the transfer was bit-for-bit accurate.

Run the same command (with the right path) on the source VM and destination VM via SSH to get their checksums, then compare all three by eye.

---

## Step 9 — Clean up the local temporary copy

```bash
rm -rf LOCAL_TMP local_folder.tar.gz
```
> Deletes the staged copy from your local machine once you've confirmed the destination has it, freeing up local disk space.

---

### Notes
- `scp -r` is fine for folders with a moderate number of files; for folders with **many small files**, the tar-stream alternatives in Steps 4 and 6 are noticeably faster since they avoid per-file SSH handshake overhead.
- Make sure `LOCAL_TMP` has enough free disk space for the folder before Step 4 — check with `df -h .`
- If either VM uses a **non-default SSH port**, add `-P <port>` to every `scp` command and `-p <port>` to every `ssh` command.
- If you use SSH keys instead of a password, no extra flags are needed as long as the key is loaded (`ssh-add -l` to check) or referenced via `-i /path/to/key` on each command.
