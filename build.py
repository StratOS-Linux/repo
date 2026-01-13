#!/usr/bin/env python3
import os, sys, subprocess
import tempfile, shutil
import glob, re
from pathlib import Path
from rich.live import Live
from rich.panel import Panel
from rich.console import Console
from rich.text import Text
from rich import print as rprint
import git  # pip install GitPython

console = Console()

def handle_error(line):
    console.print(f"[red]Error on line {line}[/red]")
    sys.exit(1)

def run_command(label, cmd):
    output_lines = []
    max_lines = 80  # max lines to keep in the panel

    with Live(Panel(f"[cyan]{label} …\n\nWaiting for output..."), refresh_per_second=10, console=console) as live:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

        for line in proc.stdout:
            output_lines.append(line.rstrip())
            # Keep only last max_lines lines for display
            output_lines = output_lines[-max_lines:]
            
            # Update live panel with current output
            panel_text = Text(f"{label} …\n\n", justify="left")
            panel_text.append("\n".join(output_lines))
            live.update(Panel(panel_text, title="Running"))
        
        proc.wait()
        if proc.returncode == 0:
            live.update(Panel(f"[bold green]{label} … ✅", title="Success"))
            return 0
        else:
            live.update(Panel(f"[bold red]{label} … ❌", title="Failed"))
            console.print("\n".join(output_lines))
            return 1

def run_makepkg(dir_path, pkg_label):
    """Run makepkg in directory"""
    prev_dir = os.getcwd()
    try:
        os.chdir(dir_path)
        return run_command(f"Building {pkg_label}", ["sudo", "-u", "builder", "makepkg", "-fsc", "--noconfirm"])
    finally:
        os.chdir(prev_dir)

def run_pacman_install(pkg_pattern, pkg_label):
    """Install package with pacman - handles glob patterns"""
    pkg_files = glob.glob(pkg_pattern)
    if not pkg_files:
        console.print(f"[red]No package found: {pkg_pattern}[/red]")
        return 1
    
    cmd = ["sudo", "pacman", "-U"] + pkg_files + ["--noconfirm"]
    return run_command(f"Installing {pkg_label}", cmd)

def setup_environment():
    """Configure git and pacman"""
    git_config = {
        "http.lowSpeedLimit": "0",
        "http.lowSpeedTime": "999999",
        "http.noEPSV": "true"
    }
    for key, value in git_config.items():
        subprocess.run(f"git config --global {key} {value}", shell=True, check=True)
    
    # Configure pacman.conf
    pacman_conf = Path("/etc/pacman.conf")
    with pacman_conf.open('r') as f:
        content = f.read()
    
    lines_to_uncomment = ['#.*VerbosePkgLists', '#.*ILoveCandy']
    for pattern in lines_to_uncomment:
        content = re.sub(rf'^{re.escape(pattern)}', lambda m: m.group(0).split()[0], content, flags=re.MULTILINE)
    
    with pacman_conf.open('w') as f:
        f.write(content + "\nVerbosePkgLists\nILoveCandy\n")
    
    # Configure makepkg.conf
    subprocess.run(["sudo", "sed", "-i", 's/purge debug/purge !debug/g', "/etc/makepkg.conf"], check=True)
    subprocess.run(["sudo", "sed", "-i", 's/^#* *GPGKEY *=.*/GPGKEY="19A421C3D15C8B7C672F0FACC4B8A73AB86B9411"/', "/etc/makepkg.conf"], check=True)
    
    subprocess.run(["sed", "-i", 's/^#*\\(PACKAGER=\\).*/\\1"StratOS team <stratos-linux@gmail.com>"/', "/etc/makepkg.conf"], check=True)
    # Add stratos repo
    with open("/etc/pacman.conf", "a") as f:
        f.write("\n[stratos]\nSigLevel = Optional TrustAll\nServer = http://repo.stratos-linux.org/\n")

def create_dummy_user():
    """Create builder user for makepkg"""
    subprocess.run("sudo useradd -m -s /bin/bash builder || true ", shell=True, check=True)
    subprocess.run("sudo usermod -aG wheel builder", shell=True, check=True)
    
    with open("/etc/sudoers", "a") as f:
        f.write("\n%wheel ALL=(ALL) NOPASSWD:ALL\n")
    
    console.print("[yellow]Adding Eli Zaretskii and ElKowar keys...[/yellow]")
    for key in ["E78DAE0F3115E06B", "862BA3D7D7760F13"]:
        subprocess.run(f"sudo -u builder gpg -q --recv {key}", shell=True, check=False)
        trust_cmd = f"sudo -u builder gpg --batch --command-fd 0 --edit-key {key}"
        subprocess.run(trust_cmd, input="trust\n5\ny\nquit\n", text=True, shell=True, check=False, stderr=subprocess.DEVNULL)
    console.print("[green]Done.[/green]")

def get_pkg_version(pkgbuild_path):
    """Get pkgver from PKGBUILD using shell command with awk."""
    try:
        # Run awk on the file path
        cmd = f"awk -F= '/^pkgver=/ {{ v = $2 }} /^pkgrel=/ {{ r = $2 }} END {{ print v \"-\" r }}' {pkgbuild_path}"
        # cmd = f"awk -F= '/^pkgver=/ {{print $2}}' {pkgbuild_path}"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True)
        version = result.stdout.strip()
        return str(version)
    except Exception:
        return "none"
    
def get_aur_version(package):
    """Get pkgver-pkgrel from AUR .SRCINFO using curl and regex."""
    try:
        # Fetch .SRCINFO from AUR gitweb
        cmd = f"curl -s https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h={package}"
        result = subprocess.run(cmd, capture_output=True, text=True, shell=True, check=True)
        srcinfo = result.stdout
        
        # Extract pkgver and pkgrel using regex
        pkgver_match = re.search(r'pkgver\s*=\s*([\d\w.-]+)', srcinfo)
        pkgrel_match = re.search(r'pkgrel\s*=\s*([\d\w.-]+)', srcinfo)
        
        if pkgver_match and pkgrel_match:
            return f"{pkgver_match.group(1)}-{pkgrel_match.group(1)}"
        elif pkgver_match:
            return pkgver_match.group(1)
        else:
            return "none"
    except Exception:
        return "none"
    
def clone_and_build_if_needed(package, dir_path):
    """Clone and build package only if needed (mimic shell logic)"""
    dir_path = Path(dir_path)
    
    # 1. Get local PKGBUILD version
    pkgbuild_local = dir_path / f"PKGBUILDS/{package}/PKGBUILD"
    if pkgbuild_local.exists():
        local_version = get_pkg_version(pkgbuild_local)
    else:
        local_version = "none"
    
    # 2. Get AUR version
    aur_version = get_aur_version(package) or None
    
    # 3. Find built package file in x86_64
    pkg_files = list(dir_path.glob(f"x86_64/*{package}*.pkg.tar.zst"))
    if pkg_files:
        # mimic shell grep -Po '(?<=pkgver=)...'
        # extract pkgver from PKGBUILD we copied into PKGBUILDS (this matches shell logic)
        actual_local_version = local_version
    else:
        actual_local_version = None
    
    console.print(f"Checking {package}: local={local_version}, AUR={aur_version}")
    
    # 4. Decide to build (matches shell condition)
    # NOTE I've skipped the actual_local_version logic here.
    if not (pkg_files and (local_version == aur_version)):
        temp_dir = Path("/tmp") / package
        shutil.rmtree(temp_dir, ignore_errors=True)
        subprocess.run(f"git clone --quiet https://aur.archlinux.org/{package}.git {str(temp_dir)} || git clone --branch {package} --single-branch https://github.com/archlinux/aur.git {str(temp_dir)}", shell=True, check=True)
        subprocess.run(f"sudo chmod -R 777 {str(temp_dir)} || true", shell=True, check=True)
        subprocess.run(f"sudo chown -R builder {str(temp_dir)} || true", shell=True, check=True)
        
        os.chdir(temp_dir)
        # Copy PKGBUILD to local repo
        pkgbuild_dest = dir_path / f"PKGBUILDS/{package}"
        pkgbuild_dest.mkdir(parents=True, exist_ok=True)
        shutil.copy("PKGBUILD", pkgbuild_dest / "PKGBUILD")
        
        success = run_makepkg(str(temp_dir), package)
        if success == 0:
            for pkg_file in glob.glob("*.pkg.tar.zst"):
                # shutil.move(pkg_file, dir_path / "x86_64")
                src = Path(pkg_file)
                dst_dir = dir_path / "x86_64"
                dst = dst_dir / src.name
                if dst.exists(): dst.unlink()
                shutil.move(str(src), str(dst))
        
        os.chdir(str(dir_path.parent))
        shutil.rmtree(temp_dir)
       #else:
        # console.print(f"[green]{package} is up-to-date[/green]")

'''
def build_and_package_scenefx(x86_64_path): 
    if not Path(x86_64_path).is_dir():
        console.print(f"[red]Directory does not exist: {x86_64_path}[/red]")
        return
    
    print(f"Directory confirmed: {x86_64_path}")
    
    # Now find scenefx file
    scenefx_pattern = None
    for item in x86_64_path.iterdir():
        print(f"Checking: {item.name}")
        if "scenefx0.4" in item.name and item.suffixes == [".pkg", ".tar", ".zst"]:
            scenefx_pattern = item
            break
    
    if scenefx_pattern:
        print(f"Found: {scenefx_pattern}")
        run_pacman_install(str(scenefx_pattern), "scenefx0.4")
    else:
        console.print("[red]No scenefx0.4 package found[/red]")
    return
'''

def handle_grab(dp: str):
    subprocess.run(f"mkdir -p /tmp/grab", shell=True, check=True)
    subprocess.run(f"cp {dp}/PKGBUILDS/grab/PKGBUILD /tmp/grab", shell=True, check=True)
    subprocess.run(f"cd /tmp/grab", shell=True, check=True)
    subprocess.run(f"sudo chmod -R 777 /tmp/grab", shell=True, check=True)
    subprocess.run(f"sudo -u builder makepkg -cfs --noconfirm",shell=True, check=True)
    subprocess.run(f" cp *.pkg.tar.zst {dp}/x86_64/", shell=True, check=True)
    subprocess.run(f"cd {dp}",shell=True,check=True)

def build_and_package(dp: str):
    """Main build function"""
    # build_and_package_scenefx(Path(f"{dir_path}/x86_64"))

    # dir_path is /repo
    #handle_grab(f"{str(dp)}")
    handle_stratmacs(f"{str(dp)}/PKGBUILDS/stratmacs/PKGBUILD")

    subprocess.run("sudo pacman -Syy",shell=True, check=True)

    # StratOS GitHub packages
    stratos_packages = [
        
        #"maneki-neko",
        "stratos-starship-hyprland-config",
        "rockers",
        "sddm-astronaut-theme",
        "stratmacs-config",
        "stratos-bin",
        "stratos-btop-config",
        "stratos-calamares-config",
        "stratos-eww-config",
        "stratos-eww-niri-config",
        "stratos-fish-config",
        "stratos-fonts",
	"stratos-ghostty-config",
        "stratos-grub",
        "stratos-hyprland-config",
        "stratos-kitty-config",
        "stratos-mako-config",
        "stratos-niri-config",
        "stratos-rofi-config",
        "stratos-starship-config",
        "stratos-swaync-config",
        "stratos-wallpapers",
        "stratos-waybar-config",
        "tokyonight-gtk-theme"
    ]
    
    for package in stratos_packages:
        build_stratos_package(package, dp)

    aur_packages = [
        #"bibata-cursor-theme-bin",
       # "ckbcomp",
        "calamares",
        "eww",
        "gruvbox-plus-icon-theme-git",
        "gnome-shell-extension-blur-my-shell",
        "gnome-shell-extension-burn-my-windows-git",
        "gnome-shell-extension-dash-to-dock",
        "gnome-shell-extension-forge-git",
        "gnome-shell-extension-space-bar-git",
        "nwg-clipman",
        "octopi",
	"pacsea-bin",
       # "pandoc-bin",
        "paru",
        #"paru-bin",
        #"protonup-qt",
        #"python-clickgen",
        #"python-inputs",
        #"python-steam",
        "python-vdf",
        #"pyprland",
        "rate-mirrors-bin",
         "swayfx",
        "swayfx-git",
        # "scenefx0.4",
       # "scenefx-git",
        "sway-nvidia",
        "ventoy-bin",
        "vicinae-bin",
        "yay-bin",
        "zen-browser-bin"
    ]
    
    for pkg in aur_packages:
        clone_and_build_if_needed(pkg, dp)
    
        
    
def handle_stratmacs(dp: str):
    """Handle stratmacs version checking and building"""
    arch_pkgbuild_url = "https://gitlab.archlinux.org/archlinux/packaging/packages/emacs/-/raw/main/PKGBUILD"
    arch_pkgbuild_content = subprocess.run(f"curl -s {arch_pkgbuild_url}", capture_output=True, shell=True, text=True, check=True).stdout
    cmd = """awk -F= '/^pkgver=/ { v = $2 } /^pkgrel=/ { r = $2 } END { print v "-" r }'"""
    arch_version = subprocess.run(cmd, shell=True, input=arch_pkgbuild_content, capture_output=True, text=True).stdout.strip()

    local_pkgbuild = Path(dp) # / f"PKGBUILDS/stratmacs/PKGBUILD" # /repo/PKGBUILDS/stratmacs/PKGBUILD
    try:
        local_content = local_pkgbuild.read_text()
        # local_content = subprocess.run(f"sudo cat {str(local_pkgbuild)}", capture_output=True, text=True, check=False)
        # local_content = subprocess.run("sudo ls -l /repo/PKGBUILDS", shell=True, capture_output=True, text=True, check=False)
        cmd = """awk -F= '/^pkgver=/ { v = $2 } /^pkgrel=/ { r = $2 } END { print v "-" r }'"""
        local_version = subprocess.run(cmd, shell=True, input=local_content, capture_output=True, text=True).stdout.strip()
    except PermissionError:
        console.print("[red]Can't read PKGBUILD[/red]")
        local_version = "none"
        try:
            local_content = subprocess.run(f"sudo ls {str(local_pkgbuild)}", shell=True, capture_output=True, text=True, check=False).stderr
        except:
            pass
    except FileNotFoundError:
        console.print(f"[purple]{local_pkgbuild}[/purple] [red]not found[/red]")
        local_version = "none"
  
    console.print(f"Checking Stratmacs: local={local_version}, Arch={arch_version}")
    if arch_version != local_version:
        temp_dir = Path("/tmp/stratmacs")
        shutil.rmtree(temp_dir, ignore_errors=True)
        temp_dir.mkdir()
        
        subprocess.run(f"git clone --quiet https://github.com/StratOS-Linux/stratmacs {str(temp_dir)}", shell=True, check=True)
        subprocess.run(f"sudo chmod -R 777 {str(temp_dir)}", shell=True, check=True)
        
        os.chdir(temp_dir)
        success = run_makepkg("/tmp/stratmacs", "stratmacs")
        if success == 0:
            for pkg_file in glob.glob("*.pkg.tar.zst"):
                if "debug" not in pkg_file:
                    shutil.copy(pkg_file, Path(dp).parents[2] / "x86_64") # Path(dp).parents[2] is /repo
            shutil.copy("PKGBUILD", Path(dp))
        
        os.chdir(str(Path.cwd().parent))
        shutil.rmtree(temp_dir)
    # else:
        # console.print(f"[green]Stratmacs is up-to-date[/green]")

def build_stratos_package(package, dir_path):
    """Build StratOS GitHub package if needed, only if versions differ"""
    dir_path = Path(dir_path)
    pkgbuild_local = dir_path / f"PKGBUILDS/{package}/PKGBUILD"
    
    # Get local version (pkgver-pkgrel) from PKGBUILD
    if pkgbuild_local.exists():
        local_pkgver = local_pkgrel = None
        with open(pkgbuild_local) as f:
            for line in f:
                if line.startswith("pkgver="):
                    local_pkgver = line.split("=", 1)[1].strip().strip('"\'')
                elif line.startswith("pkgrel="):
                    local_pkgrel = line.split("=", 1)[1].strip().strip('"\'')
                if local_pkgver and local_pkgrel:
                    break
        if local_pkgver and local_pkgrel:
            local_version = f"{local_pkgver}-{local_pkgrel}"
        else:
            local_version = "none"
    else:
        local_version = "none"
    
    # Get StratOS version (pkgver-pkgrel) from remote PKGBUILD
    try:
        stratos_srcinfo = subprocess.run(
            f"curl -s https://raw.githubusercontent.com/StratOS-Linux/{package}/refs/heads/main/PKGBUILD",
            shell=True, capture_output=True, text=True, check=True
        ).stdout
        stratos_ver_match = re.search(r'^pkgver\s*=\s*([^\s#]+)', stratos_srcinfo, re.MULTILINE)
        stratos_rel_match = re.search(r'^pkgrel\s*=\s*([^\s#]+)', stratos_srcinfo, re.MULTILINE)
        if stratos_ver_match and stratos_rel_match:
            stratos_version = f"{stratos_ver_match.group(1)}-{stratos_rel_match.group(1)}"
        else:
            stratos_version = "none"
    except Exception:
        stratos_version = "none"

    # Check if a built package already exists
    pkg_files = list(dir_path.glob(f"x86_64/*{package}*.pkg.tar.zst"))
    if pkg_files:
        # with open(pkg_files[0], 'rb') as f:  # just to mimic shell version logic
        actual_local_version = local_version
    else:
        actual_local_version = None

    console.print(f"Checking {package}: local={local_version}, StratOS={stratos_version}")

    # Only rebuild if versions differ or built package missing
    if not (pkg_files and (local_version == stratos_version)):
        temp_dir = Path(f"/tmp/{package}")
        shutil.rmtree(temp_dir, ignore_errors=True)
        subprocess.run(
            f"git clone --quiet https://github.com/stratos-linux/{package}.git {str(temp_dir)}",
            shell=True, check=True
        )
        subprocess.run(f"sudo chmod -R 777 {str(temp_dir)}", shell=True, check=True)
        subprocess.run(f"sudo chown -R builder {str(temp_dir)}", shell=True, check=True)

        os.chdir(temp_dir)
        # Copy PKGBUILD to local dir
        (dir_path / f"PKGBUILDS/{package}").mkdir(parents=True, exist_ok=True)
        shutil.copy("PKGBUILD", dir_path / f"PKGBUILDS/{package}/PKGBUILD")

        success = run_makepkg(str(temp_dir), package)
        if success == 0:
            for pkg_file in glob.glob("*.pkg.tar.zst"):
                if "debug" not in pkg_file:
                    src = Path(pkg_file)
                    dst_dir = dir_path / "x86_64"
                    dst = dst_dir / src.name
                    if dst.exists():
                        dst.unlink()
                    shutil.move(str(src), str(dst))
        os.chdir(str(Path.cwd().parent))
        shutil.rmtree(temp_dir)
    # else:
    #     console.print(f"[green]{package} is up-to-date[/green]")
        
def initialize_and_push(dir_path):
    """Update repository database"""
    dir_path = Path(dir_path)
    db_path = dir_path / "x86_64/stratos.db.tar.zst"
    
    if db_path.exists():
        subprocess.run(f"repo-remove {str(db_path)}", shell=True, cwd=dir_path, check=True)
    
    # Remove old db files
    for pattern in ["stratos.db*", "stratos.files*"]:
        for f in dir_path.glob(f"x86_64/{pattern}"):
            f.unlink()
    
    console.print("[red][bold]PACKAGES HAVE BEEN REBUILT![/bold][/red]")
    subprocess.run(f"rm -rf stratos.db* stratos.files*", shell=True, check=True)
    subprocess.run(f"repo-add -pqn {str(db_path)} x86_64/*.pkg.tar.zst", shell=True, cwd=dir_path, check=True) # this was -pq

def main():
    """Main execution"""
    if not Path("/repo").exists():
        console.print("[yellow]GITHUB_TOKEN check skipped in container[/yellow]")
    
    create_dummy_user()
    # setup_environment()  # Commented out as in original
    
    dir_path = "/repo" # Path.cwd()
    build_and_package(dir_path)
    initialize_and_push(dir_path)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[yellow]Interrupted by user[/yellow]")
    except Exception as e:
        console.print(f"[red]Fatal error: {e}[/red]")
        sys.exit(1)
