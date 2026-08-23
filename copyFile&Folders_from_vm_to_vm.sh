#!/bin/bash
#
# copy_to_remote.sh
#
# Interactively copies a file or folder from THIS (source) VM to a remote
# (destination) VM over SSH/rsync, using password auth entered at runtime.
# Includes dependency checks, connectivity checks, and dry-run support.
#
# Usage:
#   ./copy_to_remote.sh                       # prompts for everything
#   ./copy_to_remote.sh --dry-run             # show what would be copied, no changes
#   ./copy_to_remote.sh --source=/path/to/x --dest=/path/to/y   # skip those prompts
#
# Requires: bash, and either apt/yum/dnf as a package manager (for auto-install
# of rsync/sshpass if missing). If the destination path needs elevated
# permissions to write to, the destination user should have (passwordless) sudo.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults / flags
# ---------------------------------------------------------------------------
SRC_PATH=""
DEST_PATH=""
DRY_RUN=false
USE_SUDO=false
SSH_PORT=22
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="./file_transfer_logs"
LOG_FILE="${LOG_DIR}/copy_${TIMESTAMP}.log"

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --sudo) USE_SUDO=true ;;
        --source=*) SRC_PATH="${arg#*=}" ;;
        --dest=*) DEST_PATH="${arg#*=}" ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^#//'
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
mkdir -p "$LOG_DIR"

log() {
    local level="$1"; shift
    local msg="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR" "$1"
    log "ERROR" "Aborting. Full log at: $LOG_FILE"
    exit 1
}

trap 'error_exit "Script interrupted or failed at line $LINENO."' ERR
trap 'unset DEST_PASSWORD DEST_PASSWORD_CONFIRM' EXIT

log "INFO" "=== Starting file transfer script (dry_run=$DRY_RUN) ==="

# ---------------------------------------------------------------------------
# Prompt for source path (if not passed as --source=)
# ---------------------------------------------------------------------------
if [ -z "$SRC_PATH" ]; then
    read -rp "Source path on THIS machine (file or folder): " SRC_PATH
fi
if [ ! -e "$SRC_PATH" ]; then
    error_exit "Source path '$SRC_PATH' does not exist on this VM."
fi

IS_DIR=false
if [ -d "$SRC_PATH" ]; then
    IS_DIR=true
    # Ensure trailing slash on directories so rsync copies contents predictably
    [[ "$SRC_PATH" == */ ]] || SRC_PATH="${SRC_PATH}/"
fi

# ---------------------------------------------------------------------------
# Local dependency check (no auto-install — just verify and stop if missing)
# ---------------------------------------------------------------------------
check_local_cmd() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        log "INFO" "'$cmd' is installed locally."
    else
        error_exit "'$cmd' is not installed on this (source) machine. Please install '$cmd' and re-run the script."
    fi
}

check_local_cmd rsync
check_local_cmd sshpass

# ---------------------------------------------------------------------------
# Prompt for destination VM details
# ---------------------------------------------------------------------------
validate_ip_or_host() {
    local val="$1"
    if [[ "$val" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local IFS='.'
        read -ra octets <<< "$val"
        for o in "${octets[@]}"; do
            if (( o < 0 || o > 255 )); then return 1; fi
        done
        return 0
    elif [[ "$val" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        return 0
    fi
    return 1
}

echo ""
echo "===== Destination VM Details ====="

while true; do
    read -rp "Destination IP or hostname: " DEST_HOST
    if [ -z "$DEST_HOST" ]; then
        echo "IP/hostname cannot be empty."
        continue
    fi
    if ! validate_ip_or_host "$DEST_HOST"; then
        echo "That doesn't look like a valid IP or hostname. Try again."
        continue
    fi
    break
done

while true; do
    read -rp "Destination SSH username: " DEST_USER
    [ -n "$DEST_USER" ] && break
    echo "Username cannot be empty."
done

while true; do
    read -rsp "Destination SSH password: " DEST_PASSWORD
    echo ""
    read -rsp "Confirm password: " DEST_PASSWORD_CONFIRM
    echo ""
    if [ -z "$DEST_PASSWORD" ]; then
        echo "Password cannot be empty."
        continue
    fi
    if [ "$DEST_PASSWORD" != "$DEST_PASSWORD_CONFIRM" ]; then
        echo "Passwords do not match. Try again."
        continue
    fi
    unset DEST_PASSWORD_CONFIRM
    break
done

read -rp "SSH port [default: 22]: " PORT_INPUT
if [ -n "$PORT_INPUT" ]; then
    SSH_PORT="$PORT_INPUT"
fi

if [ -z "$DEST_PATH" ]; then
    read -rp "Destination path on remote machine: " DEST_PATH
fi
[ -n "$DEST_PATH" ] || error_exit "Destination path cannot be empty."

if [ "$USE_SUDO" = false ]; then
    read -rp "Does writing to '$DEST_PATH' on the destination require sudo/root? [y/N]: " NEEDS_SUDO
    [[ "$NEEDS_SUDO" =~ ^[Yy]$ ]] && USE_SUDO=true
fi

log "INFO" "Target: ${DEST_USER}@${DEST_HOST}:${SSH_PORT}  Source: $SRC_PATH  Dest: $DEST_PATH  Sudo: $USE_SUDO"

SSH_OPTS=(-p "$SSH_PORT" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

remote_run() {
    sshpass -p "$DEST_PASSWORD" ssh "${SSH_OPTS[@]}" "${DEST_USER}@${DEST_HOST}" "$@"
}

# ---------------------------------------------------------------------------
# Test SSH connectivity + credentials
# ---------------------------------------------------------------------------
log "INFO" "Testing SSH connectivity to ${DEST_HOST}..."
if ! remote_run "echo connected" >>"$LOG_FILE" 2>&1; then
    error_exit "Could not SSH to ${DEST_USER}@${DEST_HOST}:${SSH_PORT}. Check IP, username, password, port, and firewall/security group rules."
fi
log "INFO" "SSH connectivity OK."

# ---------------------------------------------------------------------------
# Confirm sudo works on destination, if needed
# ---------------------------------------------------------------------------
if [ "$USE_SUDO" = true ]; then
    log "INFO" "Checking sudo access on destination..."
    if ! remote_run "sudo -n true" >>"$LOG_FILE" 2>&1; then
        log "WARN" "Passwordless sudo not confirmed for '$DEST_USER' on destination."
        log "WARN" "If NOPASSWD sudo is not configured, the copy step below may hang or fail."
        read -rp "Continue anyway? [y/N]: " CONT
        [[ "$CONT" =~ ^[Yy]$ ]] || error_exit "Aborted by user due to sudo concern."
    else
        log "INFO" "Passwordless sudo confirmed."
    fi
fi

# ---------------------------------------------------------------------------
# Check rsync exists on destination (no auto-install — just verify and stop if missing)
# ---------------------------------------------------------------------------
log "INFO" "Checking rsync on destination..."
if remote_run "command -v rsync" >>"$LOG_FILE" 2>&1; then
    log "INFO" "rsync is installed on destination."
else
    error_exit "rsync is not installed on the destination machine. Please install rsync there and re-run the script."
fi

# ---------------------------------------------------------------------------
# Run the copy
# ---------------------------------------------------------------------------
RSYNC_FLAGS=(-az --human-readable --info=progress2)
[ "$USE_SUDO" = true ] && RSYNC_FLAGS+=(--rsync-path="sudo rsync")
if [ "$DRY_RUN" = true ]; then
    RSYNC_FLAGS+=(--dry-run)
    log "INFO" "Running in DRY-RUN mode — no files will actually be changed."
fi

log "INFO" "Starting rsync: ${SRC_PATH} -> ${DEST_USER}@${DEST_HOST}:${DEST_PATH}"

set +e
sshpass -p "$DEST_PASSWORD" rsync "${RSYNC_FLAGS[@]}" \
    -e "ssh ${SSH_OPTS[*]}" \
    "$SRC_PATH" "${DEST_USER}@${DEST_HOST}:${DEST_PATH}" 2>&1 | tee -a "$LOG_FILE"
RSYNC_STATUS=${PIPESTATUS[0]}
set -e

if [ "$RSYNC_STATUS" -ne 0 ]; then
    error_exit "rsync failed with exit code $RSYNC_STATUS. See $LOG_FILE for details."
fi

if [ "$DRY_RUN" = true ]; then
    log "INFO" "Dry run finished. No changes were made. Re-run without --dry-run to apply."
    exit 0
fi

log "INFO" "=== Transfer completed successfully. Log: $LOG_FILE ==="
echo ""
echo "=================================================="
echo "✅ COPY COMPLETED — 100%"
echo "   ${SRC_PATH}  →  ${DEST_USER}@${DEST_HOST}:${DEST_PATH}"
echo "=================================================="
echo "Full log saved to: $LOG_FILE"
