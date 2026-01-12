#!/usr/bin/env bash
# pacman -Sy
useradd -m builder -s /bin/bash
usermod -aG wheel builder
echo "%wheel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
