#!/bin/bash
# set -e # exit on error
# Function to handle errors
handle_error() {
    echo "Error on line $1"
    exit 1
}

# Trap errors
trap 'handle_error $LINENO' ERR
[ -d /workspace ] && git config --global --add safe.directory /workspace && git config --global --add safe.directory /workspace/repoctl

# Set up Arch Linux environment
setup_environment() {  
    git config --global http.lowSpeedLimit 0
    git config --global http.lowSpeedTime 999999
    git config --global http.noEPSV true
    git config --global http.postBuffer 15728640000

    export URL="https://$(git config --get remote.origin.url | sed -E 's|.+[:/]([^:/]+)/([^/.]+)(\.git)?|\1|').github.io/repo/x86_64"
    echo -e "\n[stratos]\nSigLevel = Optional TrustAll\nServer = $URL" | sudo tee -a /etc/pacman.conf
    sudo sed -i 's/purge debug/purge !debug/g' /etc/makepkg.conf
    sudo sed -i 's/^#* *GPGKEY *=.*/GPGKEY="19A421C3D15C8B7C672F0FACC4B8A73AB86B9411"/' /etc/makepkg.conf # add zstg's public key
    sed -i 's/^#*\(PACKAGER=\).*/\1"StratOS team <stratos-linux@gmail.com>"/' /etc/makepkg.conf
}

# Create dummy user for makepkg
create_dummy_user() {
    dir=$PWD
    sudo useradd -m builder -s /bin/bash
    sudo usermod -aG wheel builder
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers
    sudo -u builder curl -sS https://github.com/elkowar.gpg | gpg --dearmor > elkowar.gpg && sudo pacman-key --add elkowar.gpg
    sudo -u builder curl -sS https://github.com/web-flow.gpg | gpg --dearmor > web-flow.gpg && sudo pacman-key --add web-flow.gpg
}

# Build and package software
build_and_package() {
    sudo pacman -Sy
    dir="$PWD"
    sudo git config --global init.defaultBranch main

    # # sudo pacman -U $dir/x86_64/ckbcomp-1.227-1-any.pkg.tar.zst --noconfirm
    # sudo pacman -U $dir/x86_64/repoctl-0.22.2-1-x86_64.pkg.tar.zst --noconfirm
    # cd $dir/PKGBUILDS/rockers/
    # sudo chmod -R 777 ../rockers
    # sudo -u builder makepkg -cfs --noconfirm # --sign
    # rm -f **debug**.pkg.tar.zst
    # rm -rf src/ pkg/
    # mv *.pkg.tar.zst $dir/x86_64/
    # cd $dir/

    # mkdir -p /tmp/litefm && chmod -R 777 /tmp/litefm
    # cp $dir/PKGBUILDS/litefm/PKGBUILD /tmp/litefm
    # cd /tmp/litefm
    # rm -f $dir/x86_64/**litefm**.pkg.tar.zst
    # sudo -u builder makepkg -cfs --noconfirm # --sign
    # mv *.pkg.tar.zst $dir/x86_64/
    # cd $dir/

    # mkdir -p /tmp/ckbcomp
    # cp $dir/PKGBUILDS/ckbcomp/PKGBUILD /tmp/ckbcomp
    # cd /tmp/ckbcomp
    # sudo chmod -R 777 /tmp/ckbcomp
    # sudo -u builder makepkg -cfs --noconfirm
    # rm -f **debug**.pkg.tar.zst
    # cp *.pkg.tar.zst $dir/x86_64/
    # sudo pacman -U *.pkg.tar.zst --noconfirm
    # cd $dir

    cd "$dir"/PKGBUILDS/calamares
    sudo chmod -R 777 "$dir"/PKGBUILDS/calamares
    sudo -u builder makepkg -cfs --noconfirm # --sign
    echo "Removing Qt Calamares build..."
    sudo rm -v **qt5**.pkg.tar.zst
    sudo rm -rfv *.tar.gz **debug**.pkg.tar.zst calamares/ src/ pkg/
    rm -fv "$dir"/x86_64/**calamares**.pkg.tar.zst
    mv -v *.pkg.tar.zst "$dir"/x86_64/
    cd "$dir"

    mkdir -p /tmp/grab
    cp "$dir"/PKGBUILDS/grab/PKGBUILD /tmp/grab
    cd /tmp/grab
    sudo chmod -R 777 /tmp/grab
    sudo -u builder makepkg -cfs --noconfirm
    rm -f **debug**.pkg.tar.zst
    cp *.pkg.tar.zst "$dir"/x86_64/
    cd "$dir"

    mkdir -p /tmp/maneki-neko
    cp "$dir"/PKGBUILDS/maneki-neko/PKGBUILD /tmp/maneki-neko
    cd /tmp/maneki-neko
    sudo chmod -R 777 /tmp/maneki-neko
    sudo -u builder makepkg -cfs --noconfirm
    rm -f **debug**.pkg.tar.zst
    cp *.pkg.tar.zst "$dir"/x86_64/
    cd "$dir"

    local packages=(
        "albert" 
        "aura-bin"
        # "aurutils" 
        "bibata-cursor-theme-bin"
        # "brave-bin"
        # #"eww"
        # "google-chrome"
        # "gruvbox-plus-icon-theme-git" 
        # "libadwaita-without-adwaita-git" 
        # "mkinitcpio-openswap" 
        # "nwg-clipman"
        "nwg-dock-hyprland-bin" 
        # "octopi"
        "oh-my-zsh-git"
        "pamac-all"
        "pandoc-bin" 
        "python-clickgen"
        # "pyprland"
        # #"repoctl"
        # "rua"
        "swayfx"
        "sway-nvidia"
        "swayosd-git"
        "ventoy-bin" 
        "yay-bin"
    )

    for i in "${packages[@]}"; do
        git clone https://aur.archlinux.org/"$i"
        sudo chmod -R 777 ./"$i" 
        cd "$i"
        mkdir -p "$dir/PKGBUILDS/$i"/
        cp PKGBUILD "$dir/PKGBUILDS/$i"/PKGBUILD
        sudo -u builder makepkg -cfs --noconfirm # --sign
        rm -rf "$dir/x86_64/$i"**.pkg.tar.zst
        mv *.pkg.tar.zst "$dir"/x86_64/
        cd ..
        rm -rf "$i"
    done
    # sudo pacman -U $dir/x86_64/**repoctl** --noconfirm
    # sudo pacman -U $dir/x86_64/**aurutils** --noconfirm
    
}

# Initialize and push to GitHub
initialize_and_push() {
    export URL="$(git config --get remote.origin.url | sed -E 's|.+[:/]([^:/]+)/([^/.]+)(\.git)?|\1|')"
    cd "$dir"
    bash ./initialize.sh
    sudo git config --global user.name 'github-actions[bot]'
    sudo git config --global user.email 'github-actions[bot]@users.noreply.github.com'
    sudo git add .
    sudo git commit -am "Update packages"
    # sudo git pull
    sudo git push "https://x-access-token:${GITHUB_TOKEN}@github.com/$URL/repo" --force
}

# Main function
main() {
    create_dummy_user
    setup_environment
    build_and_package
    initialize_and_push
}

# Ensure GITHUB_TOKEN is set
if [ ! -d "/workspace" ] && [ "$GITHUB_TOKEN" = "" ]; then
    echo "GITHUB_TOKEN is not set. Please set it - following the instructions in README.md - before running this script."
    exit 1
fi

# Execute main function
main
