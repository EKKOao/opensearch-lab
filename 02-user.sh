#!/bin/bash
set -e

if ! getent group opensearch >/dev/null; then
    groupadd -g 1122 -r opensearch
fi

if ! id -u opensearch >/dev/null 2>&1; then
    useradd -u 1122 -g 1122 -r -s /bin/bash -m -d /home/opensearch opensearch
fi
