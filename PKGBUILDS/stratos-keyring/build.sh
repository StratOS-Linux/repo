#!/usr/env/bin/bash
## NOTE this file isn't really necessary because pacman-key doesn't load the keys, gpg does.
sudo pacman-key --init
sudo pacman -Rns stratos-keyring --noconfirm
rm -rf /tmp/stratos-keyring 2>/dev/null
cp -r ../stratos-keyring /tmp
sudo chown -R $USER:$USER /tmp/stratos-keyring
cd /tmp/stratos-keyring
rm -f *.pkg.tar.zst 2>/dev/null
makepkg -sifc --noconfirm