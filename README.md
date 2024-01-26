<img title="" src="https://i.imgur.com/Kq4ER0L.png" alt="Linux Club Logo" data-align="center">

# StratOS-repo

## About

- A custom Arch repo hosted on GitHub.

- Meant for use in [StratOS](https://github.com/lugvitc/LUG_custom_distro) (A Bedrock-derived distro made by the Linux Club OS Team).

## Installation

- To add this repo to your Arch distribution, open `/etc/pacman.conf` and add this at the end :

```bash
[StratOS-repo]
SigLevel = Optional TrustAll
Server = https://StratOS-Linux.github.io/StratOS-repo/x86_64
```
