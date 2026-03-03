#!/bin/bash
set -e

HOSTNAME=$(hostname)
NFS_SERVER_IP="192.168.56.11"
SHARE_PATH="/mnt/opensearch/backup"

if [ "$HOSTNAME" == "os1" ]; then

    apt-get update -y
    apt-get install -y nfs-kernel-server

    chown 1122:1122 "$SHARE_PATH"
    chmod 775 "$SHARE_PATH"

    if ! grep -q "$SHARE_PATH" /etc/exports; then
        echo "$SHARE_PATH 192.168.56.0/24(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    fi

    exportfs -a
    systemctl restart nfs-kernel-server

    # Verify
    touch "$SHARE_PATH/verify_nfs.txt"

else

    apt-get update -y
    apt-get install -y nfs-common

    mkdir -p "$SHARE_PATH"
    chown 1122:1122 "$SHARE_PATH"

    # Check if NFS is already mounted
    if ! grep -q "$NFS_SERVER_IP:$SHARE_PATH" /proc/mounts; then
        mount "$NFS_SERVER_IP:$SHARE_PATH" "$SHARE_PATH"
        echo "$NFS_SERVER_IP:$SHARE_PATH $SHARE_PATH nfs defaults 0 0" >> /etc/fstab
    fi
fi
