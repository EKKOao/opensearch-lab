#!/bin/bash
set -e

CURRENT_NAME="enp0s8"
NEW_NAME="prod"

if ip link show "$NEW_NAME" >/dev/null 2>&1; then
    exit 0
fi

if [ -d "/sys/class/net/$CURRENT_NAME" ]; then
    MAC=$(cat /sys/class/net/$CURRENT_NAME/address)
else
    exit 1
fi

cat <<EOF > /etc/systemd/network/10-rename-prod.link
[Match]
MACAddress=$MAC

[Link]
Name=$NEW_NAME
EOF

sed -i "s/$CURRENT_NAME/$NEW_NAME/g" /etc/netplan/*.yaml

ip link set $CURRENT_NAME down
ip link set $CURRENT_NAME name $NEW_NAME
ip link set $NEW_NAME up

netplan apply