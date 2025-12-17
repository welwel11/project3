#!/bin/bash

# Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

print_section() {
  local title="$1"
  echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${MAGENTA}║  $title${RESET}$(printf ' %.0s' {1..$(($(tput cols)-${#title}-4))})${MAGENTA}║${RESET}"
  echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${RESET}"
}

run_with_spinner() {
  local msg="$1"
  local cmd="$2"

  echo -ne "${CYAN}${msg}...${RESET}"
  bash -c "$cmd" &>/tmp/zivpn_spinner.log &
  local pid=$!

  local delay=0.1
  local spinstr='|/-\'
  while kill -0 $pid 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  wait $pid

  if [ $? -eq 0 ]; then
    echo -e " ${GREEN}✔️${RESET}"
  else
    echo -e " ${RED}❌ Error${RESET}"
    cat /tmp/zivpn_spinner.log
    exit 1
  fi
  rm -f /tmp/zivpn_spinner.log
}

print_section "🔍 CHECKING PREVIOUS INSTALLATION"
if [ -f /usr/local/bin/zivpn ]; then
  echo -e "${YELLOW}⚠️ ZIVPN already installed. Aborting.${RESET}"
  exit 1
fi

print_section "📦 UPDATING SYSTEM"
run_with_spinner "Updating packages" "apt update && apt upgrade -y"

print_section "⬇️ DOWNLOADING ZIVPN"
wget -q https://github.com/ChristopherAGT/zivpn-tunnel-udp/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

mkdir -p /etc/zivpn
wget -q https://raw.githubusercontent.com/welwel11/project3/main/config.json -O /etc/zivpn/config.json

print_section "🔐 GENERATING SSL"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
-subj "/CN=zivpn" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt &>/dev/null

print_section "⚙️ SYSTEM OPTIMIZATION"
sysctl -w net.core.rmem_max=16777216 &>/dev/null
sysctl -w net.core.wmem_max=16777216 &>/dev/null

print_section "🧩 CREATING SERVICE"
cat >/etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZIVPN UDP Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn

print_section "🌐 FIREWALL & IPTABLES"
iface=$(ip route | awk '/default/ {print $5}')
iptables -t nat -A PREROUTING -i $iface -p udp --dport 6000:19999 -j DNAT --to :5667
ufw allow 6000:19999/udp
ufw allow 5667/udp

print_section "⬇️ INSTALLING MENU"
wget -q https://raw.githubusercontent.com/welwel11/project3/main/panel-udp-zivpn.sh \
-O /usr/local/bin/menu-zivpn
chmod +x /usr/local/bin/menu-zivpn

print_section "🖥️ AUTO MENU LOGIN"
AUTO_MENU_MARKER="# AUTO MENU ZIVPN"
if ! grep -q "$AUTO_MENU_MARKER" /root/.bashrc; then
cat <<'EOF' >> /root/.bashrc

# AUTO MENU ZIVPN
if [ -n "$SSH_CONNECTION" ]; then
  clear
  menu-zivpn
fi
EOF
fi

print_section "✅ INSTALLATION COMPLETE"
echo -e "${GREEN}ZIVPN UDP Installed Successfully${RESET}"
echo -e "${GREEN}Auto menu active: reconnect SSH to see menu${RESET}"