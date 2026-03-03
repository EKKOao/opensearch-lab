#!/bin/bash
set -e
SERVICE_FILE="/etc/systemd/system/opensearch.service"
OS_HOME="/mnt/opensearch/home"
OS_CONF="$OS_HOME/config"

cat <<EOF > $SERVICE_FILE
[Unit]
Description=OpenSearch
Documentation=https://opensearch.org/docs/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
RuntimeDirectory=opensearch
PrivateTmp=true

Environment=OPENSEARCH_HOME=$OS_HOME
Environment=OPENSEARCH_PATH_CONF=$OS_CONF
Environment=OPENSEARCH_INITIAL_ADMIN_PASSWORD=StrongPass123!

# OpenSearch Java Options
Environment="OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g"

WorkingDirectory=$OS_HOME
User=opensearch
Group=opensearch
ExecStart=$OS_HOME/bin/opensearch -p /run/opensearch/opensearch.pid --quiet

StandardOutput=journal
StandardError=inherit
LimitNOFILE=65535
LimitNPROC=4096
LimitAS=infinity
LimitFSIZE=infinity
LimitMEMLOCK=infinity
TimeoutStartSec=75
TimeoutStopSec=0
KillSignal=SIGTERM
KillMode=process
SendSIGKILL=no
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable opensearch

echo "done 11"