#!/usr/bin/env bash
# Mirrors a local directory to a remote directory over SFTP via lftp,
# deleting anything on the remote that's no longer present locally.
#
# Usage: upload.sh LOCAL_DIR REMOTE_DIR [EXCLUDE_REGEX]
#   EXCLUDE_REGEX, if given, is passed to lftp mirror's -x as an extended
#   regex (matched against each entry's path relative to LOCAL_DIR/
#   REMOTE_DIR) to exclude from *both* the upload and the delete pass —
#   e.g. so a site-root deploy doesn't delete sibling PR preview folders
#   it doesn't know about.
#
# Required env: SSH_HOST, SSH_USERNAME, PORT, CONNECT_PROGRAM (the latter
# two are config-sftp.sh's outputs).
set -euo pipefail

LOCAL_DIR="${1:?Usage: upload.sh LOCAL_DIR REMOTE_DIR [EXCLUDE_REGEX]}"
REMOTE_DIR="${2:?Usage: upload.sh LOCAL_DIR REMOTE_DIR [EXCLUDE_REGEX]}"
EXCLUDE_REGEX="${3:-}"

: "${SSH_HOST:?SSH_HOST is required}"
: "${SSH_USERNAME:?SSH_USERNAME is required}"
: "${PORT:?PORT is required (see config-sftp.sh)}"
: "${CONNECT_PROGRAM:?CONNECT_PROGRAM is required (see config-sftp.sh)}"

EXCLUDE_ARG=()
if [ -n "$EXCLUDE_REGEX" ]; then
  EXCLUDE_ARG=(-x "$EXCLUDE_REGEX")
fi

# No quotes around $CONNECT_PROGRAM: lftp's `set` takes the rest of the
# line as the literal value, quotes included — wrapping it in "..." makes
# lftp try to exec a program literally named `"ssh -i ... "` (with the
# quote characters in the filename) and fail silently into an FTP-style
# anonymous-login hang instead of ever running ssh.
lftp -e "
set sftp:connect-program $CONNECT_PROGRAM
open sftp://${SSH_USERNAME}@${SSH_HOST}:${PORT}
mkdir -p $REMOTE_DIR
mirror -R --delete --verbose ${EXCLUDE_ARG[*]} $LOCAL_DIR $REMOTE_DIR
bye
"
