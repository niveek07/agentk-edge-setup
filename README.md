# agentk-edge-setup

Setup script for a Raspberry Pi edge device.
It installs Cockpit, configures Fail2Ban for SSH and Cockpit, mounts a USB to install Autosol from `/media/usb/Autosol/*.deb`, and adds a figlet/lolcat login banner.

## One-liner (download and run)

Run without sudo. The script uses sudo where needed.

```bash
bash -c 'curl -fsSL https://raw.githubusercontent.com/niveek07/agentk-edge-setup/main/AgentK_pi_setup.sh -o /tmp/agentk-setup.sh && bash /tmp/agentk-setup.sh'
```

## Git clone (for easy updates)

```bash
sudo apt-get update && sudo apt-get install -y git
```
```bash
git clone https://github.com/niveek07/agentk-edge-setup.git
cd agentk-edge-setup
```
```bash
chmod +x AgentK_pi_setup.sh      # first time only
bash AgentK_pi_setup.sh          # not sudo
```
```bash
# update later
git pull
```

## Requirements

* Raspberry Pi OS (Debian based)
* Internet access for apt and fonts
* USB stick with the Autosol `.deb` at `/Autosol/`
* https://autosoln.com/

##  Cameron DO NOT FORGET THIS
```
arm_boost=1
arm_freq=1300
core_freq=525
over_voltage=6
gpu_freq=700
```
```bash
sudo apt-get update && sudo apt-get upgrade -y
```
```bash
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
```
```bash
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

## What the script does

* Updates apt and installs: Cockpit, Fail2Ban, cron, figlet, lolcat, git, python3, vim, wget, libraspberrypi-bin.
* Finds the first USB partition that is not `mmcblk` or `sda2`, mounts it at `/media/usb`, and installs the Autosol `.deb` found under `/media/usb/Autosol/`.
* Writes the banner into `/etc/bash.bashrc` starting at line 61. The banner uses figlet and lolcat and prints basic system info on login.
* Logs to `~/AgentK_pi_setup.log` when run without sudo. If you ran the whole script with sudo, the log is `/root/AgentK_pi_setup.log`.

## Cockpit

* Cockpit is installed as `cockpit` and enabled.
* Access it in a browser at `https://<device>:9090`.
* The cert is self-signed by Cockpit. Your browser will show “Not secure” until you trust it. No custom SSL is added here.
* https://cockpit-project.org/

## Fail2Ban

* Two jails are enabled: `sshd` and `cockpit`.
* Backend is `systemd`. Cockpit jail reads failures from the journal.
* Defaults: bantime 1h, findtime 10m, maxretry 3.
* This blocks repeated failed logins for SSH and for the Cockpit web UI.

## License

MIT (see `LICENSE`)

