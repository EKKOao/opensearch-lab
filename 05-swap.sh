#!/bin/bash
set -e

swapoff -a

sed -i '/swap/s/^/#/' /etc/fstab

if [ $(swapon --show | wc -l) -eq 0 ]; then
    echo "Swap is disabled."
else
    echo "Swap might still be active."
    swapon --show
fi
