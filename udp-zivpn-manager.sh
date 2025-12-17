#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════╗
# ║        🛡️ ZIVPN UDP TUNNEL MANAGEMENT PANEL – ENHANCED           ║
# ╚════════════════════════════════════════════════════════════════════╝

# 🎨 Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# 🧭 Architecture detection
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  ARCH_TEXT="AMD64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH_TEXT="ARM64"
else
  ARCH_TEXT="Unknown"
fi

# ╔══════════════════════════════════════════════════╗
# ║ 🔍 FUNCTION: Show ports used by zivpn             ║
# ╚══════════════════════════════════════════════════╝
mostrar_puertos_zivpn() {
  # Get PID of zivpn process if running
  PID=$(pgrep -f /usr/local/bin/zivpn)
  if [[ -z "$PID" ]]; then
    echo -e " Ports: ${RED}Unable to detect zivpn process.${RESET}"
    return
  fi

  # Use ss if available
  if command -v ss &>/dev/null; then
    PUERTOS=$(ss -tulnp | grep "$PID" | awk '{print $5}' | cut -d':' -f2 | sort -u | tr '\n' ',' | sed 's/,$//')
  else
    # fallback to netstat
    PUERTOS=$(netstat -tulnp 2>/dev/null | grep "$PID" | awk '{print $4}' | rev | cut -d':' -f1 | rev | sort -u | tr '\n' ',' | sed 's/,$//')
  fi

  if [[ -z "$PUERTOS" ]]; then
    echo -e " Ports: ${YELLOW}No open ports detected.${RESET}"
  else
    echo -e " Ports: ${GREEN}$PUERTOS${RESET}"
  fi
}

# ╔══════════════════════════════════════════════════╗
# ║ 🔍 FUNCTION: Show fixed port and iptables         ║
# ╚══════════════════════════════════════════════════╝
mostrar_puerto_iptables() {
  local PUERTO="5667"
  local IPTABLES="6000-19999"
  echo -e " ${YELLOW}📛 Port:${RESET} ${GREEN}$PUERTO${RESET}   ${RED}🔥 Iptables:${RESET} ${CYAN}$IPTABLES${RESET}"
}

# ╔══════════════════════════════════════════════════╗
# ║ 🔍 FUNCTION: Show ZIVPN service status            ║
# ╚══════════════════════════════════════════════════╝
mostrar_estado_servicio() {
  if [ -f /usr/local/bin/zivpn ] && [ -f /etc/systemd/system/zivpn.service ]; then
    systemctl is-active --quiet zivpn.service
    if [ $? -eq 0 ]; then
      echo -e " 🟢 ZIVPN UDP service installed and active"
      mostrar_puerto_iptables
    else
      echo -e " 🟡 ZIVPN UDP service installed but ${YELLOW}not active${RESET}"
      mostrar_puerto_iptables
    fi
  else
    echo -e " 🔴 ZIVPN UDP service ${RED}not installed${RESET}"
  fi
}

# ╔══════════════════════════════════════════════════╗
# ║ 🔍 FUNCTION: Show iptables fix status             ║
# ╚══════════════════════════════════════════════════╝
mostrar_estado_fix() {
  if [ -f /etc/zivpn-iptables-fix-applied ]; then
    echo -e "${GREEN}[ON]${RESET}"
  else
    echo -e "${RED}[OFF]${RESET}"
  fi
}

# ╔══════════════════════════════════════════════════╗
# ║ 🌀 Spinner                                       ║
# ╚══════════════════════════════════════════════════╝
spinner() {
  local pid=$!
  local delay=0.1
  local spinstr='|/-\'
  while ps -p $pid &>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
}

# ╔══════════════════════════════════════════════════╗
# ║ 📋 Main menu                                     ║
# ╚══════════════════════════════════════════════════╝
mostrar_menu() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "           🛠️ ${GREEN}ZIVPN UDP TUNNEL MANAGER${RESET}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

  # Show architecture
  echo -e " 🔍 Detected architecture: ${YELLOW}$ARCH_TEXT${RESET}"

  # Show service status
  mostrar_estado_servicio

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -ne " ${YELLOW}1.${RESET} 🚀 Install UDP Service (${BLUE}AMD64${RESET})\n"
  echo -ne " ${YELLOW}2.${RESET} 📦 Install UDP Service (${GREEN}ARM64${RESET})\n"
  echo -ne " ${YELLOW}3.${RESET} ❌ Uninstall UDP Service\n"
  echo -ne " ${YELLOW}4.${RESET} 🔁 Apply persistent iptables fix $(mostrar_estado_fix)\n"
  echo -ne " ${YELLOW}5.${RESET} 🔙 Exit\n"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -ne "📤 ${BLUE}Select an option:${RESET} "
}

# ╔══════════════════════════════════════════════════╗
# ║ 🚀 INSTALL / UNINSTALL FUNCTIONS                 ║
# ╚══════════════════════════════════════════════════╝

instalar_amd() {
  clear
  echo -e "${GREEN}🚀 Downloading installer for AMD64...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/install-amd.sh -O install-amd.sh &
  spinner
  if [[ ! -f install-amd.sh ]]; then
    echo -e "${RED}❌ Error: Failed to download the file.${RESET}"
    read -p "Press Enter to continue..."
    return
  fi
  echo -e "${GREEN}🔧 Running installation...${RESET}"
  bash install-amd.sh
  rm -f install-amd.sh
  echo -e "${GREEN}✅ Installation completed.${RESET}"
  read -p "Press Enter to continue..."
}

instalar_arm() {
  clear
  echo -e "${GREEN}📦 Downloading installer for ARM64...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/install-arm.sh -O install-arm.sh &
  spinner
  if [[ ! -f install-arm.sh ]]; then
    echo -e "${RED}❌ Error: Failed to download the file.${RESET}"
    read -p "Press Enter to continue..."
    return
  fi
  echo -e "${GREEN}🔧 Running installation...${RESET}"
  bash install-arm.sh
  rm -f install-arm.sh
  echo -e "${GREEN}✅ Installation completed.${RESET}"
  read -p "Press Enter to continue..."
}

desinstalar_udp() {
  clear
  echo -e "${RED}🧹 Downloading uninstall script...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/uninstall.sh -O uninstall.sh &
  spinner
  if [[ ! -f uninstall.sh ]]; then
    echo -e "${RED}❌ Error: Failed to download the file.${RESET}"
    read -p "Press Enter to continue..."
    return
  fi
  echo -e "${RED}⚙️ Running uninstallation...${RESET}"
  bash uninstall.sh
  rm -f uninstall.sh
  echo -e "${GREEN}✅ Uninstallation completed.${RESET}"
  read -p "Press Enter to continue..."
}

# ╔══════════════════════════════════════════════════╗
# ║ 🛠️ FUNCTION: Apply persistent iptables fix       ║
# ╚══════════════════════════════════════════════════╝
fix_iptables_zivpn() {
  clear
  echo -e "${CYAN}🔧 Applying persistent iptables fix for ZIVPN...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/zivpn-iptables-fix.sh -O zivpn-iptables-fix.sh
  if [[ ! -f zivpn-iptables-fix.sh ]]; then
    echo -e "${RED}❌ Error: Failed to download the fix.${RESET}"
    read -p "Press Enter to continue..."
    return
  fi
  bash zivpn-iptables-fix.sh
  local res=$?
  rm -f zivpn-iptables-fix.sh
  if [[ $res -eq 0 ]]; then
    # Create indicator file for ON state
    touch /etc/zivpn-iptables-fix-applied 2>/dev/null || echo -e "${YELLOW}⚠️ Unable to create status indicator file.${RESET}"
    echo -e "${GREEN}✅ Fix applied successfully.${RESET}"
  else
    echo -e "${RED}❌ An error occurred while applying the fix.${RESET}"
  fi
  read -p "Press Enter to continue..."
}

# 🔁 Main menu loop
while true; do
  clear
  mostrar_menu
  read -r opcion
  case $opcion in
    1) instalar_amd ;;
    2) instalar_arm ;;
    3) desinstalar_udp ;;
    4) fix_iptables_zivpn ;;
    5) echo -e "${YELLOW}👋 Goodbye!${RESET}"; exit 0 ;;
    *) echo -e "${RED}❌ Invalid option. Try again.${RESET}"; sleep 2 ;;
  esac
done