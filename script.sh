#!/bin/bash

# ===================================
# Semi-Harening Script
# Run as: root or sudo
# Author: 0xAmanita / Yldevier
# ===================================

set -euo pipefail

# ---------- CONFIG ----------

NEW_USER="amanita"
SSH_PORT=22
TIMEZONE="Asia/Manila"

# ---------- COLORS ----------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log(){ echo -e "${GREEN}[Check] $1${NC}"; }
warn(){ echo -e "${YELLOW}[Warning!] $1${NC}"; }
error(){ echo -e "${RED}[Error!] $1${NC}"; exit 1; }
section(){ echo -e "\n${CYAN}==== $1 ====${NC}"; }

# ---------- ROOT CHECK ----------

[[ $EUID -ne 0 ]] && error "Run as root"

# ===================================

# 1. SYSTEM UPDATE

# ===================================

section "System Update"

apt update -y
apt upgrade -y
apt autoremove -y

log "System updated"

# ===================================

# 2. CREATE USER SAFELY

# ===================================

section "User Creation"

if id "$NEW_USER" &>/dev/null; then
warn "User exists, skipping"
else
useradd -m -s /bin/bash "$NEW_USER"
passwd "$NEW_USER"
usermod -aG sudo "$NEW_USER"
log "User created"
fi

# =================================== 

# 3. COPY SSH KEYS TO NEW USER 

# =================================== 

section "3. Copying SSH Keys to $NEW_USER" 

if [[ -d /root/.ssh ]]; then
    rsync --archive --chown="$NEW_USER:$NEW_USER" /root/.ssh /home/"$NEW_USER" 
    chmod 700 /home/"$NEW_USER"/.ssh 
    chmod 600 /home/"$NEW_USER"/.ssh/authorized_keys 2>/dev/null || true 
    log "SSH keys copied to /home/$NEW_USER/.ssh" 
else 
    warn "No .ssh directory found in /root. Skipping SSH key copy."
fi

# ===================================

# 4. SSH BACKUP + SAFETY CHECK

# ===================================

section "SSH Config Backup"

SSH_CONFIG="/etc/ssh/sshd_config"
cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%F-%H%M%S)"

# Validate config BEFORE changes

sshd -t || error "Invalid SSH config BEFORE changes"

# ===================================

# 5. APPLY SAFE SSH HARDENING

# ===================================

section "SSH Hardening (safe apply)"

apply_ssh() {
local key="$1"
local value="$2"

```
if grep -qE "^#?${key}" "$SSH_CONFIG"; then
    sed -i "s|^#\?${key}.*|${key} ${value}|" "$SSH_CONFIG"
else
    echo "${key} ${value}" >> "$SSH_CONFIG"
fi
```

}

apply_ssh "Port" "$SSH_PORT"
apply_ssh "PermitRootLogin" "no"
apply_ssh "PubkeyAuthentication" "yes"
apply_ssh "X11Forwarding" "no"
apply_ssh "MaxAuthTries" "3"
apply_ssh "LoginGraceTime" "20"
apply_ssh "PermitEmptyPasswords" "no"

# DO NOT disable password auth blindly (prevents lockout)

# apply_ssh "PasswordAuthentication" "no"

# Validate BEFORE restart

sshd -t || error "SSH CONFIG INVALID AFTER CHANGES"

# Restart SSH safely

systemctl restart ssh

# Confirm SSH is alive

ss -tlnp | grep ssh || error "SSH NOT LISTENING AFTER RESTART"

log "SSH validated and running safely"

# ===================================

# 6. FIREWALL (ONLY AFTER SSH CONFIRMED)

# ===================================

section "Firewall Setup"

apt install -y ufw

ufw default deny incoming
ufw default allow outgoing

ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp

# SAFETY CHECK BEFORE ENABLING

warn "Enabling firewall AFTER SSH validation"

ufw --force enable

ufw status verbose

log "Firewall active safely"

# ===================================

# 7. FAIL2BAN

# ===================================

section "Fail2Ban"

apt install -y fail2ban

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = $SSH_PORT
EOF

systemctl enable fail2ban
systemctl restart fail2ban

log "Fail2Ban active"


# ===================================

# 8. Shell Aliases

# ===================================

section "8. Setting up Shell Aliases"

BASHRC="/home/$NEW_USER/.bashrc"

cat >> "$BASHRC" <<'EOF'

# --- Custom Aliases ---
alias ls='lsd'
alias ll='lsd -la'
alias lt='lsd --tree'
alias cat='bat --paging=never'
alias update='sudo apt update && sudo apt upgrade -y'
alias ports='ss -tulnp'
alias myip='curl -s ifconfig.me'
EOF

log "Aliases added to $BASHRC"

# =============================================================================

# 9. KERNEL HARDENING via sysctl

# =============================================================================

section "9. Kernel Hardening (sysctl)"

cat > /etc/sysctl.d/99-hardening.conf <<EOF
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sysctl --system > /dev/null 2>&1
log "Kernel hardening applied."

# =============================================================================

# 9. UNATTENDED SECURITY UPGRADES

# =============================================================================

section "10. Enabling Unattended Security Upgrades"

apt install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades
log "Unattended security upgrades enabled."

# ===================================

# 11. VERIFY FINAL ACCESS SAFETY

# ===================================

section "Final Safety Check"

warn "DO NOT CLOSE CURRENT SESSION YET"

ss -tlnp | grep ssh
systemctl status ssh --no-pager | head -20

log "System is safe"

# ===================================

# DONE

# ===================================

section "COMPLETE"

echo -e "${GREEN}"
echo "User: $NEW_USER"
echo "SSH Port: $SSH_PORT"
echo "Root login disabled: yes"
echo "Firewall enabled safely"
echo -e "${NC}"

warn "Open a SECOND SSH session and test login BEFORE exiting this one"
