#!/bin/bash
set -e

URL="https://artifacts.opensearch.org/releases/bundle/opensearch/3.3.2/opensearch-3.3.2-linux-x64.tar.gz"
TMP_FILE="/tmp/opensearch.tar.gz"
DEST_DIR="/mnt/opensearch/home"

wget -q -O "$TMP_FILE" "$URL"

tar -xzf "$TMP_FILE" -C "$DEST_DIR" --strip-components=1

rm -f "$TMP_FILE"

chown -R 1122:1122 "$DEST_DIR"