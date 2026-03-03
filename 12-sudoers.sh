#!/bin/bash
set -e

SUDO_FILE="/etc/sudoers.d/opensearch"

# Allow systemctl commands without password
cat <<EOF > $SUDO_FILE
opensearch ALL=(root) NOPASSWD: /usr/bin/systemctl start opensearch.service
opensearch ALL=(root) NOPASSWD: /usr/bin/systemctl stop opensearch.service
opensearch ALL=(root) NOPASSWD: /usr/bin/systemctl restart opensearch.service
opensearch ALL=(root) NOPASSWD: /usr/bin/systemctl status opensearch.service
opensearch ALL=(root) NOPASSWD: /usr/bin/systemctl status opensearch
EOF

# Strict permissions are required for sudoers files
chmod 0440 $SUDO_FILE
