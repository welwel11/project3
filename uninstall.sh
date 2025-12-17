#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════╗
# ║       ❌  ZIVPN UDP UNINSTALLER                                      ║
# ║       🧽 Complete system and administration panel cleanup           ║
# ║       👤 Author: Zahid Islam / Adapted by Christopher                ║
# ╚══════════════════════════════════════════════════════════════════════╝

# 🎨 Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

# Function to print sections
print_section() {
  local title="$1"
  echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════╗${RESET}"
  printf "${MAGENTA}║ %-66s ║\n" "$title"
  echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════╝${RESET}"
}

clear
print_section "🧹 STARTING ZiVPN UNINSTALLATION"

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🛑 STOPPING SERVICES"
systemctl stop zivpn.service &>/dev/null
systemctl stop zivpn_backfill.service &>/dev/null
systemctl disable zivpn.service &>/dev/null
systemctl disable zivpn_backfill.service &>/dev/null

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🧽 REMOVING BINARIES AND CONFIGURATION FILES"
rm -f /etc/systemd/system/zivpn.service
rm -f /etc/systemd/system/zivpn_backfill.service
rm -rf /etc/zivpn
rm -f /usr/local/bin/zivpn
killall zivpn &>/dev/null

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🔥 REMOVING IPTABLES RULES"
iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
iptables -t nat -D PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 &>/dev/null

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🗑️ REMOVING INDICATORS AND FIXES"
rm -f /etc/zivpn-iptables-fix-applied

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🧨 REMOVING ADMINISTRATION PANEL"
rm -f /usr/local/bin/menu-zivpn
rm -f /etc/zivpn/usuarios.db
rm -f /etc/zivpn/autoclean.conf
rm -f /etc/systemd/system/zivpn-autoclean.timer
rm -f /etc/systemd/system/zivpn-autoclean.service
systemctl daemon-reexec &>/dev/null
systemctl daemon-reload &>/dev/null

# ╔════════════════════════════════════════════════════════════════════╗
print_section "📋 FINAL STATUS CHECK"
if pgrep "zivpn" &>/dev/null; then
  echo -e "${RED}⚠️  Process is still running.${RESET}"
else
  echo -e "${GREEN}✅ Process stopped successfully.${RESET}"
fi

if [ -e "/usr/local/bin/zivpn" ]; then
  echo -e "${YELLOW}⚠️  Binary still present. Please try again.${RESET}"
else
  echo -e "${GREEN}✅ Binary removed successfully.${RESET}"
fi

if [ -f /usr/local/bin/menu-zivpn ]; then
  echo -e "${RED}⚠️  Administration panel was not removed.${RESET}"
else
  echo -e "${GREEN}✅ Administration panel removed successfully.${RESET}"
fi

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🧼 CACHE AND SWAP CLEANUP"
echo 3 > /proc/sys/vm/drop_caches
sysctl -w vm.drop_caches=3 &>/dev/null
swapoff -a && swapon -a

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🏁 COMPLETED"
echo -e "${GREEN}✅ UDP ZiVPN and its panel have been uninstalled successfully.${RESET}"