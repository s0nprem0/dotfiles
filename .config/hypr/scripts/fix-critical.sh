#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo " Fix Script — run with: sudo bash $0"
echo "========================================"

[ "$EUID" -eq 0 ] || { echo "Run with sudo"; exit 1; }

# Get actual user
USER_HOME=$(eval echo ~${SUDO_USER})

echo "=== 1. Install firewall (ufw) ==="
pacman -S --noconfirm ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.0.0/16 to any port 22 comment 'SSH from LAN'
ufw --force enable
systemctl enable --now ufw

echo "=== 2. Disable systemd-networkd ==="
systemctl disable --now systemd-networkd

echo "=== 3. Remove orphans ==="
pacman -Rns --noconfirm $(pacman -Qdtq) 2>/dev/null || echo "No orphans"

echo "=== 4. Clean package cache ==="
paccache -rk 2 2>/dev/null || pacman -Sc --noconfirm

echo "=== 5. Remove stray binary ==="
rm -f "$USER_HOME/.equilotl"

echo "=== 6. Disable broken swaync service ==="
sudo -u "$SUDO_USER" systemctl --user disable --now swaync.service 2>/dev/null || true

echo "=== Done ==="
echo "Reboot recommended to apply network changes."
