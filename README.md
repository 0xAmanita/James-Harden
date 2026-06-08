# James Harden (Semi-Hardening Script)

A Bash script designed to automate the initial setup and security hardening of a Debian/Ubuntu-based server.

## Features

* **System Updates:** Automates `apt update`, `upgrade`, and `dist-upgrade`.
* **User Management:** Creates a new sudo user (default: `amanita`) and migrates SSH keys from root.
* **SSH Hardening:** Disables root login and password authentication; enforces key-based auth.
* **Firewall & Protection:** Configures UFW (SSH, HTTP, HTTPS) and sets up Fail2Ban with custom jails.
* **Kernel Hardening:** Applies `sysctl` configurations to protect against IP spoofing and SYN attacks.
* **Automated Maintenance:** Enables `unattended-upgrades` for security patches.
* **Quality of Life:** Installs `python3`, `bat` (syntax highlighting), and `lsd` (modern `ls`) with pre-configured aliases.

## Usage

1.  **Prepare the script:**
    ```bash
    chmod +x script.sh
    ```

2.  **Configure variables:**
    Edit the `0. CUSTOM CONFIGURATION` section in `script.sh` to set your desired `NEW_USER`, `SSH_PORT`, and `TIMEZONE` (default: `Asia/Manila`).

3.  **Run as root:**
    ```bash
    sudo ./script.sh
    ```

## Important Notes

* **SSH Testing:** Do **not** close your current session until you have verified that you can log in via a new terminal using the new user and SSH keys.
* **Root Access:** Once the script completes, root login via SSH will be disabled by default.

---
**Author:** 0xAmanita / Yldevier
