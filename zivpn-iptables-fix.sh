#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║   🔐 PERSISTENT IPTABLES RULES FIX FOR ZIVPN UDP TUNNEL          ║
# ║   👤 Author: ChristopherAGT                                     ║
# ║   🛠️ Fixes loss of iptables rules after reboot                 ║
# ╚══════════════════════════════════════════════════════════════════╝

# 🎨 Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
RESET="\033[0m"

echo -e "${CYAN}🔍 Detecting network interface...${RESET}"
iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

if [[ -z "$iface" ]]; then
  echo -e "${RED}❌ Unable to detect network interface. Aborting.${RESET}"
  exit 1
fi

echo -e "${CYAN}🌐 Detected interface: ${YELLOW}$iface${RESET}"

# 📌 Apply iptables rule if it does not exist
echo -e "${CYAN}🧪 Checking iptables rule for ZIVPN...${RESET}"
if iptables -t nat -C PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null; then
  echo -e "${YELLOW}⚠️ Rule already exists. It will not be applied again.${RESET}"
else
  echo -e "${GREEN}✅ Adding iptables rule for ZIVPN...${RESET}"
  iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
fi

# 🔥 Open ports with UFW if available
if command -v ufw &>/dev/null; then
  echo -e "${CYAN}🔓 Configuring UFW...${RESET}"
  ufw allow 6000:19999/udp &>/dev/null
  ufw allow 5667/udp &>/dev/null
fi

# 📦 Install iptables-persistent if not present
if ! dpkg -s iptables-persistent &>/dev/null; then
  echo -e "${CYAN}📦 Installing iptables-persistent to keep rules...${RESET}"
  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
  echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
  apt-get install -y iptables-persistent &>/dev/null
fi

# 💾 Save rules for reboot persistence
echo -e "${CYAN}💾 Saving rules for reboot...${RESET}"
iptables-save > /etc/iptables/rules.v4

echo -e "${GREEN}✅ Rules applied and saved successfully.${RESET}"