#!/usr/env/bin/bash
# Reset keys
sudo rm -rf /etc/pacman.d/gnupg
sudo pacman-key --init && sudo pacman-key --populate archlinux

sudo pacman -Rns stratos-keyring --noconfirm
rm -rf /tmp/stratos-keyring 2>/dev/null
cp -r ../stratos-keyring /tmp
sudo chown -R $USER:$USER /tmp/stratos-keyring
cd /tmp/stratos-keyring
rm -f *.pkg.tar.zst 2>/dev/null
makepkg -fc --noconfirm
sudo pacman -U ./*.pkg.tar.zst --noconfirm
sudo pacman-key --populate stratos