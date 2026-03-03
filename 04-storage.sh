#!/bin/bash
set -e

if ! vgs vg01 >/dev/null 2>&1; then
    DISK=$(lsblk -dn -o NAME,SIZE | grep '15G' | awk '{print "/dev/"$1}')
    pvcreate $DISK
    vgcreate vg01 $DISK
fi

create_lv() {
    local size=$1
    local name=$2
    if ! lvs vg01/$name >/dev/null 2>&1; then
        lvcreate -L $size -n $name vg01
        mkfs.xfs /dev/vg01/$name
    fi
}

create_lv 2G mnt
create_lv 4G data
create_lv 2G home
create_lv 1G logs
create_lv 4G backup

mount_and_fstab() {
    local lv=$1
    local path=$2

    mkdir -p $path
    if ! grep -q "$path " /proc/mounts; then
        mount /dev/vg01/$lv $path
        echo "/dev/vg01/$lv $path xfs defaults 0 0" >> /etc/fstab
    fi
}

mount_and_fstab mnt "/mnt"

mkdir -p /mnt/opensearch/data
mkdir -p /mnt/opensearch/home
mkdir -p /mnt/opensearch/logs
mkdir -p /mnt/opensearch/backup

mount_and_fstab data   "/mnt/opensearch/data"
mount_and_fstab home   "/mnt/opensearch/home"
mount_and_fstab logs   "/mnt/opensearch/logs"
mount_and_fstab backup "/mnt/opensearch/backup"

chown -R 1122:1122 /mnt/opensearch

lsblk