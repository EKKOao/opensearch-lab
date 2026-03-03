#!/bin/bash
set -e

cat <<EOF > /etc/security/limits.d/opensearch.conf
opensearch   -       nofile      65535
opensearch   hard    memlock     unlimited
opensearch   soft    memlock     unlimited
opensearch   -       nproc       4096
EOF

cat <<EOF > /etc/sysctl.d/opensearch.conf
vm.max_map_count=262144
EOF

sysctl --system
