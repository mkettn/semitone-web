#!/usr/bin/env bash
# Picks an lftp sftp:connect-program based on whichever auth secret is set,
# and writes it (plus the port) to $GITHUB_OUTPUT for later steps.
#
# Routes lftp's sftp backend through the system ssh binary so it works with
# plain key or password auth, and with SFTP-only (chrooted, no shell/rsync)
# accounts.
#
# Required env: SSH_USERNAME, and either SSH_PRIVATE_KEY or SSH_PASSWORD.
# Optional env: SSH_PORT (default 22).
set -euo pipefail

: "${SSH_USERNAME:?SSH_USERNAME is required}"

PORT="${SSH_PORT:-22}"
echo "port=${PORT}" >> "$GITHUB_OUTPUT"

# -l $SSH_USERNAME is required here even though the `open` call in
# upload.sh also embeds the username in its sftp:// URL: lftp's
# sftp:connect-program invokes this command with only host/port, never the
# username from that URL — omitting -l silently authenticates as the local
# runner's own OS user ("runner" on GitHub-hosted runners) instead, which
# the remote sshd logs as "Invalid user runner" and often just hangs on
# rather than rejecting outright.
#
# ConnectTimeout guards against a silent network-level hang (e.g. a
# firewall dropping packets instead of rejecting the connection).
if [ -n "${SSH_PRIVATE_KEY:-}" ]; then
  KEY_PATH="${RUNNER_TEMP}/deploy_key"
  printf '%s\n' "$SSH_PRIVATE_KEY" > "$KEY_PATH"
  chmod 600 "$KEY_PATH"
  # BatchMode=yes: never prompt (passphrase, unknown host, etc.) — fail
  # fast with a clear error instead of hanging forever. If this starts
  # failing, the key most likely has a passphrase; CI deploy keys must be
  # passphrase-less.
  echo "connect_program=ssh -l ${SSH_USERNAME} -i ${KEY_PATH} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=15" >> "$GITHUB_OUTPUT"
elif [ -n "${SSH_PASSWORD:-}" ]; then
  echo "SSHPASS=${SSH_PASSWORD}" >> "$GITHUB_ENV"
  # PreferredAuthentications=password (+ disabling pubkey) forces the
  # classic "Password:" prompt sshpass actually answers — without it, a
  # server offering keyboard-interactive first can leave sshpass waiting
  # on a prompt it never recognizes.
  echo "connect_program=sshpass -e ssh -l ${SSH_USERNAME} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=15" >> "$GITHUB_OUTPUT"
else
  echo "::error::Set either the SSH_PRIVATE_KEY or SSH_PASSWORD secret." >&2
  exit 1
fi
