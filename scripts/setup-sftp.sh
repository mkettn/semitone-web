#!/usr/bin/env bash
# Installs the tools config-sftp.sh and upload.sh need: lftp itself, and
# sshpass for the password-auth path (harmless to have installed even when
# a key is used instead).
set -euo pipefail

sudo apt-get update -y
sudo apt-get install -y lftp sshpass
