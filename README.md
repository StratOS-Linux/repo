
# StratOS-repo
<!-- [![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/StratOS-linux/stratos-iso) -->

## About

- A custom Arch repo hosted on GitHub

- Meant for use in [StratOS](https://github.com/StratOS-Linux/StratOS-iso) (An Arch-based meta-distro developed by the StratOS Team)

## Installation

- To add this repo to your Arch distribution, open `/etc/pacman.conf` and add this at the end :

```
[StratOS-repo]
SigLevel = Optional TrustAll
Server = https://StratOS-Linux.github.io/StratOS-repo/x86_64
```

## Building packages:
- Ensure that you have docker and docker-compose installed.
- Simply run `docker-compose up` (optionally with the `-d` flag to detach the container).

## If you want to contribute:
- Fork this repository, say to `username/StratOS-repo`.
- Create a Github personal access token [here](https://github.com/settings/tokens). 
- Copy the newly generated token and add it as the `GITHUB_TOKEN` environment variable following [these](https://www.gitpod.io/blog/securely-manage-development-secrets-with-doppler-and-gitpod#automating-doppler-secrets-injection-on-gitpod) instructions. 
- Open https://gitpod.io/#https://github.com/username/StratOS-repo. Replace `username` with your actual GitHub username.
- Gitpod will start building the packages automatically. You can interrupt it via `Ctrl-c` and modify the repo (add/modify packages). 
- [Edit build.sh](https://github.com/StratOS-Linux/StratOS-repo/blob/main/build.sh#L161) to reflect your remote.
- Add the new packages to the list in `build.sh` and simply run `docker-compose down && docker-compose up` in the integrated terminal. If you'd set `GITHUB_TOKEN` correctly, it should push to your fork, from where you can send us a PR.
