#!/usr/bin/env bash
# Mac: install Google Drive API Python libs.
set -euo pipefail

python3 -m pip install --user -q \
  google-api-python-client \
  google-auth-httplib2 \
  google-auth-oauthlib 2>/dev/null || \
  pip3 install -q google-api-python-client google-auth-httplib2 google-auth-oauthlib

echo "[google-drive] Python libs ready"
