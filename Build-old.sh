#!/usr/bin/env bash
# set -e # fail on error
shopt -s extglob
# Function to handle errors
handle_error() {
    echo "Error on line $1"
    exit 1
}
# Ensure GITHUB_TOKEN is set
if [ ! -d "/workspace" ];then
    echo "GITHUB_TOKEN is not set. Please set it - following the instructions in README.md - before running this script."
    git config --global --add safe.directory /workspace
    git config --global --add safe.directory /tmp/tokyonight-gtk-theme
    # git config --global --add safe.directory /workspace/repoctl
    # exit 1
fi
# Trap errors
trap 'handle_error $LINENO' ERR

# Set up Arch Linux environment
setup_environment() {
    git config --global http.lowSpeedLimit 0
    git config --global http.lowSpeedTime 999999
    git config --global http.noEPSV true
    git config --global --unset http.postBuffer
    sudo sed -i '/^#.*VerbosePkgLists/s/^#//' /etc/pacman.conf && \
    sudo sed -i '/^#.*ILoveCandy/s/^#//' /etc/pacman.conf && \
    sudo sed -i '/^#.*VerbosePkgLists/s/^#//' /etc/pacman.conf || \
    echo -e 'VerbosePkgLists\nILoveCandy\nVerbosePkgLists' | sudo tee -a /etc/pacman.conf
    export URL="https://$(git config --get remote.origin.url | sed -E 's|.+[:/]([^:/]+)/([^/.]+)(\.git)?|\1|').github.io/repo/x86_64"
    sudo sed -i 's/purge debug/purge !debug/g' /etc/makepkg.conf
    sudo sed -i 's/^#* *GPGKEY *=.*/GPGKEY="19A421C3D15C8B7C672F0FACC4B8A73AB86B9411"/' /etc/makepkg.conf
    sed -i 's/^#*\(PACKAGER=\).*/\1"StratOS team <stratos-linux@gmail.com>"/' /etc/makepkg.conf
    # echo -e "[stratos]\nSigLevel = Optional TrustAll\nServer = http://repo.stratos-linux.org/" | sudo tee -a /etc/pacman.conf >/dev/null
    echo -e "[stratos]\nSigLevel = Optional TrustAll\nServer = file:///home/altacee/repo/x86_64/" | sudo tee -a /etc/pacman.conf >/dev/null
}

# Create dummy user for makepkg
create_dummy_user() {
    sudo useradd -m builder -s /bin/bash
    sudo usermod -aG wheel builder
    echo '%wheel ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers >/dev/null
    sudo pacman-key --init 2>/dev/null && sudo pacman-key --populate archlinux 2>/dev/null
    sudo -u builder curl -sS https://github.com/elkowar.gpg | gpg -q --dearmor > elkowar.gpg && sudo pacman-key --add elkowar.gpg 2>/dev/null
    sudo -u builder curl -sS https://github.com/web-flow.gpg | gpg -q --dearmor > web-flow.gpg && sudo pacman-key --add web-flow.gpg 2>/dev/null
    sudo -u builder gpg -q --recv-keys 862BA3D7D7760F13
}

# Function to check version differences and build package
clone_and_build_if_needed() {
    local package="$1"
    local dir="$2"

    # Get local version (from PKGBUILD if it exists)
    if [ -f "$dir/PKGBUILDS/$package/PKGBUILD" ]; then
        local local_version
        local_version=$(grep -Po '(?<=pkgver=)[\d\w.]+' "$dir/PKGBUILDS/$package/PKGBUILD")
    else
        local_version="none"
    fi

    # Get AUR version (from AUR's .SRCINFO file)
    local aur_version
    aur_srcinfo=$(curl -s "https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=$package")
    aur_version=$(echo "$aur_srcinfo" | grep -Po '(?<=pkgver = )[\d\w.]+')
    aur_pkgrel=$(echo "$aur_srcinfo" | grep -Po '(?<=pkgrel = )[\d\w.]+')
    aur_arch="x86_64"

    echo "Checking $package: local version = $local_version, AUR version = $aur_version"
    local this_pkgbuild=("$dir"/x86_64/*"$package"*) # don't remove this
    # Only clone and build if versions differ
    if [[ "$local_version" != "$aur_version" || ! -f "${this_pkgbuild[0]}" ]]; then
        rm -rf "$package"/ 2>/dev/null # if it exists, remove it
        git clone https://aur.archlinux.org/"$package".git
        sudo chmod -R 777 ./"$package"
        cd "$package"/
        mkdir -p "$dir/PKGBUILDS/$package/"
        cp PKGBUILD "$dir/PKGBUILDS/$package"/PKGBUILD
        sudo -u builder makepkg -cfs --noconfirm
        # rm -rf "$dir/x86_64/$package"**.pkg.tar.zst
        mv *.pkg.tar.zst "$dir"/x86_64/
        cd ..
        rm -rf "$package"
    #else
    #    echo "$package is on latest AUR version - rebuild not required"
    fi
}

# Build and package software
build_and_package() {
    sudo pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
    sudo pacman-key --lsign-key 9AE4078033F8024D
    sudo pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 647F28654894E3BD457199BE38DBBDC86092693E
    sudo pacman-key --lsign-key 647F28654894E3BD457199BE38DBBDC86092693E
  #  sudo pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys ABAF11C65A2970B130ABE3C479BE3E4300411886
 #   sudo pacman-key --lsign-key ABAF11C65A2970B130ABE3C479BE3E4300411886
    
    sudo pacman -Sy --disable-download-timeout --noconfirm
    dir="$PWD"
    sudo git config --global init.defaultBranch main
    sudo pacman -S pyside6 python-inputs python-steam python-pyxdg python-psutil python-yaml python-vdf python-six python-pycryptodome python-cachetools python-requests  python-zstandard qt6-tools --noconfirm
    # sudo pacman -S scenefx  --noconfirm
    # sudo chmod -R
    # sudo pacman -R scenefx --noconfirm
    #    sudo pacman -U "$dir"/x86_64/scenefx-git-*.*.pkg.tar.zst --noconfirm
    #    sudo pacman -U "$dir"/x86_64/wlroots-git-*.pkg.tar.zst --noconfirm
    #    sudo pacman -U "$dir"/x86_64/ckbcomp-*.pkg.tar.zst --noconfirm
    cd "$dir"

    local packages=(
        "albert"
        "aura-bin"
        # "aurutils"
        "bibata-cursor-theme-bin"
	# "ckbcomp"
	# "calamares"
	"calamares-git"
        # "brave-bin"
        "eww"
        # "google-chrome"
        # "gruvbox-plus-icon-theme-git"
	"gnome-shell-extension-blur-my-shell"
	"gnome-shell-extension-burn-my-windows-git"
	"gnome-shell-extension-dash-to-dock"
	"gnome-shell-extension-forge-git"
	"gnome-shell-extension-space-bar-git"
        # "libadwaita-without-adwaita-git"
#	"linux-lqx"
#	"linux-lqx-headers"
        # "mkinitcpio-openswap"
        "nwg-clipman"
        "nwg-dock-hyprland-bin"
        "octopi"
        "oh-my-zsh-git"
        # "pamac-all"
        "pandoc-bin"
	"paru-bin"
	"protonup-qt"
        "python-clickgen"
	"python-inputs"
	"python-steam"
	"python-vdf"
        "pyprland"
        # #"repoctl"
	# "rua"
	# "swayfx-git"
	# "scenefx0.4"
	"sherlock-launcher"
	# "tokyonight-gtk-theme-git"
	# "wlroots-0.19"
	# "scenefx-git"
	# "sway-nvidia"
        # "swayosd-git"
        "ventoy-bin"
	"vicinae-bin"
        "yay-bin"
        "zen-browser-bin"
    )

    for i in "${packages[@]}"; do
        clone_and_build_if_needed "$i" "$dir" # AUR prob
    done


    # sudo pacman -U $dir/x86_64/ckbcomp-1.227-1-any.pkg.tar.zst --noconfirm
    # # sudo pacman -U $dir/x86_64/repoctl-0.22.2-1-x86_64.pkg.tar.zst --noconfirm
    # mkdir -p /tmp/litefm && chmod -R 777 /tmp/litefm
    # cp "$dir"/PKGBUILDS/litefm/PKGBUILD /tmp/litefm
    # cd /tmp/litefm
    # rm -f "$dir"/x86_64/**litefm**.pkg.tar.zst
    # sudo -u builder makepkg -cfs --noconfirm # --sign
    # mv *.pkg.tar.zst "$dir"/x86_64/
    # cd "$dir"/ 
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
    # sudo pacman -S sdl2-compat --noconfirm

   # archp_vstr="$(curl -fsSL https://gitlab.archlinux.org/archlinux/packaging/packages/emacs/-/raw/main/PKGBUILD | awk -F= '/^pkgver=|^pkgrel=/ { print $2 }')"
   # emacs_version_arch="$(echo "$archp_vstr" | awk '{print $1 "-" $2}')"
   # stratos_vstr="$(cat "$dir"/PKGBUILDS/stratmacs/PKGBUILD | awk -F= '/^pkgver=|^pkgrel=/ {print $2}')"
   # stratmacs_version="$(echo "$stratos_vstr" | awk '{print $1 "-" $2}')"
   # echo "Checking Stratmacs: local version = $stratmacs_version, Arch version = $emacs_version_arch"
   # if [[ $emacs_version_arch != $stratmacs_version ]]; then
#	# Replace the pkgver and pkgrel from the Arch PKGBUILD...
#	sed -i "s/^pkgver=.*/pkgver=${emacs_version_arch%-*}/" "$dir/PKGBUILDS/stratmacs/PKGBUILD"
#	sed -i "s/^pkgrel=.*/pkgrel=${emacs_version_arch#*-}/" "$dir/PKGBUILDS/stratmacs/PKGBUILD"
#	rm -rf /tmp/stratmacs/
#	mkdir -p /tmp/stratmacs/
#	git clone https://github.com/StratOS-Linux/stratmacs /tmp/stratmacs/
 #       ls /tmp/stratmacs/
#	exit 0
#	cd /tmp/stratmacs/
#	sudo chmod -R 777 /tmp/stratmacs/
 #       sudo -u builder makepkg -cfs --noconfirm
  #      rm -f **debug**.pkg.tar.zst
   #     cp *.pkg.tar.zst "$dir"/x86_64/
    #    cd "$dir"
     #   rm -rf /tmp/stratmacs/
    #else
    #    echo "Stratmacs v$stratmacs_version is up-to-date - rebuild not required"
#    fi
    # stratos-bin requires yay-bin, so install the produced pkg.tar.zst...
    packages=(
	"rockers"
	"sddm-astronaut-theme"
	"stratos-bin"
	"stratmacs-config"
	"stratos-btop-config"
	"stratos-calamares-config"
	"stratos-calamares-config-next"
	"stratos-eww-config"
	"stratos-eww-niri-config"
	"stratos-fish-config"
	"stratos-fonts"
	"stratos-kitty-config"
        "stratos-grub"
	"stratos-gnome-config"
        "stratos-hyprland-config"
	"stratos-mako-config"
	"stratos-niri-config"
	"stratos-rofi-config"
	"stratos-starship-hyprland-config"
	"stratos-starship-niri-config"
	"stratos-swaync-config"
	"stratos-wallpapers"
	"stratos-waybar-hyprland-config"
	"stratos-waybar-niri-config"
	"tokyonight-gtk-theme"
    )
    for package in "${packages[@]}"; do
	repo_vstr="$(curl -fsSL https://raw.githubusercontent.com/StratOS-Linux/"$package"/refs/heads/main/PKGBUILD | awk -F= '/^pkgver=|^pkgrel=/ { print $2 }')"
	repo_version="$(echo "$repo_vstr" | awk '{print $1 "-" $2}')"
	local_vstr="$(cat "$dir/PKGBUILDS/$package"/PKGBUILD | awk -F= '/^pkgver=|^pkgrel=/ {print $2}')"
	local_version="$(echo "$local_vstr" | awk '{print $1 "-" $2}')"
	echo "Checking $package: local version = $local_version, repo version = $repo_version"
	if [[ $repo_version != $local_version ]]; then
	    rm -rf /tmp/"$package"/
	    mkdir -p /tmp/"$package"/
	    # cp "$dir"/PKGBUILDS/"$package"/PKGBUILD /tmp/"$package"
	    git clone https://github.com/StratOS-Linux/"$package" /tmp/"$package"
	    cd /tmp/"$package"
	    sudo chmod -R 777 "/tmp/$package"
	    sudo chown -R builder:wheel "/tmp/$package"
	    sudo -u builder makepkg -cfs --noconfirm
	    rm -f **debug**.pkg.tar.zst
	    cp *.pkg.tar.zst "$dir"/x86_64/
	    cd "$dir"
	    cp /tmp/"$package"/PKGBUILD "$dir"/PKGBUILDS/"$package"/PKGBUILD # zstg added this
	    rm -rf /tmp/"$package"/
	#else
	#    echo "$package is up-to-date - no rebuild required"
	fi
    done
}

# Initialize and push to GitHub
initialize_and_push() {
    cd "$dir"
    #repo-remove x86_64/stratos.db.tar.zst
    #rm x86_64/stratos.db* x86_64/stratos.files* -rf
    repo-add -Rq x86_64/stratos.db.tar.zst x86_64/*.pkg.tar.zst
    #sudo git config --global user.name 'github-actions[bot]'
    #sudo git config --global user.email 'github-actions[bot]@users.noreply.github.com'
    #sudo git add .
    #sudo git commit -am "Update packages"
    #export URL=$(git config --get remote.origin.url | sed "s|^https://|https://x-access-token:${GITHUB_TOKEN}@|")
    #sudo git push "$URL" --force
}

# Main function
main() {
    create_dummy_user
    setup_environment
    build_and_package
    initialize_and_push
}
# Execute main function
main
