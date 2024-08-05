#!/bin/bash

# Function to handle errors
handle_error() {
    echo "Error on line $1"
    exit 1
}

# Trap errors
trap 'handle_error $LINENO' ERR
[ -d /workspace ] && git config --global --add safe.directory /workspace

# Set up Arch Linux environment
setup_environment() {
    dir=$(pwd)
    sudo pacman-key --init
    sudo pacman -Sy --noconfirm
    sudo pacman -U $dir/x86_64/stratos-keyring-20240804-1-x86_64.pkg.tar.zst --noconfirm # setup keyring on gitpod for makepkg --sign
    echo -e "\n[StratOS-repo]\nSigLevel = Optional TrustAll\nServer = https://StratOS-Linux.github.io/StratOS-repo/x86_64" | sudo tee -a /etc/pacman.conf
    sudo sed -i 's/purge debug/purge !debug/g' /etc/makepkg.conf
    sudo sed -i 's/^#* *GPGKEY *=.*/GPGKEY="A046BE254138E0AC1BF5F66690D63B3FE2F217ED"/' /etc/makepkg.conf # add StratOS public key
    sed -i 's/^#*\(PACKAGER=\).*/\1"StratOS team <stratos-linux@gmail.com>"/' /etc/makepkg.conf
    sudo pacman -Syy git base-devel --needed --noconfirm
    git config --global --add safe.directory /workspace
}

# Import GPG Key from GitLab
import_gpg_key() {
    echo "Importing key..."
    sudo pacman-key --init
    sudo pacman-key --populate archlinux
    # echo -e 'default-cache-ttl 34560000\nmax-cache-ttl 34560000' > ~/.gnupg/gpg-agent.conf
    # sudo pkill gpg-agent
    # gpg-agent --daemon --use-standard-socket --allow-preset-passphrase
    # echo "Radiantly2-Cable8-Headdress6-Resisting8-Affirm0" | gpg --batch --import --passphrase-fd 0 stratos-public-key.gpg
}

# Create dummy user for makepkg
create_dummy_user() {
    dir=$(pwd)
    sudo useradd -m builder -s /bin/bash
    sudo usermod -aG wheel builder
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers
    # sudo -u builder curl -sS https://github.com/elkowar.gpg | gpg --dearmor > elkowar.gpg && sudo pacman-key --add elkowar.gpg
    # sudo -u builder curl -sS https://github.com/web-flow.gpg | gpg --dearmor > web-flow.gpg && sudo pacman-key --add web-flow.gpg
    exit 1
}

# Build and package software
build_and_package() {
    dir="$(pwd)"
    sudo git config --global init.defaultBranch main

    # sudo pacman -U $dir/x86_64/ckbcomp-1.227-1-any.pkg.tar.zst --noconfirm

    # git clone https://aur.archlinux.org/kpmcore-git
    # sudo chmod -R 777 ./kpmcore-git
    # cd kpmcore-git
    # sudo -u builder makepkg -cfs --noconfirm # --sign
    # rm -f **debug**.pkg.tar.zst
    # rm -f $dir/x86_64/**kpmcore**.pkg.tar.zst
    # cp *.pkg.tar.zst $dir/x86_64/
    # cp PKGBUILD $dir/PKGBUILDS/kpmcore-git/PKGBUILD
    # sudo pacman -U *.pkg.tar.zst --noconfirm
    # cd ..
    # rm -rf kpmcore-git

    # cd $dir/PKGBUILDS/ckbcomp/
    # sudo chmod -R 777 ../ckbcomp
    # sudo -u builder makepkg -cfs --noconfirm # --sign
    # rm -f **debug**.pkg.tar.zst
    # rm -f $dir/x86_64/ckbcomp**.pkg.tar.zst
    # mv $dir/PKGBUILDS/ckbcomp/PKGBUILD /tmp && rm -rf $dir/PKGBUILDS/ckbcomp/* && mv /tmp/PKGBUILD $dir/PKGBUILDS/ckbcomp

    # cd $dir/PKGBUILDS/rockers/
    # sudo chmod -R 777 ../rockers
    # sudo -u builder makepkg -cfs --noconfirm --sign
    # rm -f **debug**.pkg.tar.zst
    # mv *.pkg.tar.zst $dir/x86_64/
    # cd $dir/

    # mkdir -p /tmp/litefm && chmod -R 777 /tmp/litefm
    # cp $dir/PKGBUILDS/litefm/PKGBUILD /tmp/litefm
    # cd /tmp/litefm
    # rm -f $dir/x86_64/**litefm**.pkg.tar.zst
    # sudo -u builder makepkg -cfs --noconfirm --sign
    # mv *.pkg.tar.zst $dir/x86_64/
    # cd $dir


    local packages=(
        # "albert" 
        # "aurutils" 
        # "bibata-cursor-theme-bin"
        # "calamares-git" 
        # "eww"
        # "gruvbox-plus-icon-theme-git" 
        # "libadwaita-without-adwaita-git" 
        # "mkinitcpio-openswap" 
        # "nwg-dock-hyprland" 
        # "pandoc-bin" 
        # "python-clickgen"
        # "rua"
        # "swayosd-git"
        # "ventoy-bin" 
        "yay-bin"
    )

    for i in "${packages[@]}"; do
        git clone https://aur.archlinux.org/$i
        sudo chmod -R 777 ./$i
        cd $i
        cp PKGBUILD $dir/PKGBUILDS/$i/PKGBUILD
        sudo -u builder makepkg -cfs --noconfirm --sign
        rm -rf $dir/x86_64/"$i"**.pkg.tar.zst
        mv *.pkg.tar.zst $dir/x86_64/
        cd ..
        rm -rf $i
    done
}

# Initialize and push to GitHub
initialize_and_push() {
    cd $dir
    bash ./initialize.sh
    sudo git config --global user.name 'github-actions[bot]'
    sudo git config --global user.email 'github-actions[bot]@users.noreply.github.com'
    # sudo git add .
    # sudo git commit -am "Update packages"
    # sudo git push "https://x-access-token:${GITHUB_TOKEN}@github.com/StratOS-Linux/StratOS-repo.git"
}

# Main function
main() {
    setup_environment
    import_gpg_key
    create_dummy_user
    build_and_package
    initialize_and_push
}

# Ensure GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN is not set. Please set it - following the instructions in README.md - before running this script."
    exit 1
fi

# Execute main function
main