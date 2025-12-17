#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════╗
# ║        INSTALLER MODUL ZIVPN UDP (FINAL FIX)                      ║
# ╚════════════════════════════════════════════════════════════════════╝

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
  local spin='|/-\'
  while kill -0 $pid 2>/dev/null; do
    printf " [%c]  " "$spin"
    spin=${spin#?}${spin%"${spin#?}"}
    sleep 0.1
    printf "\b\b\b\b\b\b"
  done
  wait $pid || { echo -e " ${RED}❌${RESET}"; cat /tmp/zivpn_spinner.log; exit 1; }
  echo -e " ${GREEN}✔${RESET}"
  rm -f /tmp/zivpn_spinner.log
}

# ╔════════════════════════════════════════════════════════════════╗
print_section "CEK INSTALASI SEBELUMNYA"
if [ -f /usr/local/bin/zivpn ] || [ -f /etc/systemd/system/zivpn.service ]; then
  echo -e "${YELLOW}ZIVPN UDP sudah terpasang. Instalasi dibatalkan.${RESET}"
  exit 1
fi

# ╔════════════════════════════════════════════════════════════════╗
print_section "UPDATE SISTEM"
run_with_spinner "Update sistem" "apt update -y && apt upgrade -y"

# ╔════════════════════════════════════════════════════════════════╗
print_section "INSTALL DEPENDENSI"
run_with_spinner "Install paket penting" "apt install -y wget curl iptables-persistent openssl"

# ╔════════════════════════════════════════════════════════════════╗
print_section "DOWNLOAD ZIVPN"
wget -q https://github.com/ChristopherAGT/zivpn-tunnel-udp/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

mkdir -p /etc/zivpn
wget -q https://raw.githubusercontent.com/welwel11/project3/main/config.json -O /etc/zivpn/config.json

# ╔════════════════════════════════════════════════════════════════╗
print_section "GENERATE SSL"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
-subj "/C=US/ST=CA/L=LA/O=ZIVPN/OU=UDP/CN=zivpn" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt

# ╔════════════════════════════════════════════════════════════════╗
print_section "OPTIMASI & IP FORWARD"
sysctl -w net.core.rmem_max=16777216 >/dev/null
sysctl -w net.core.wmem_max=16777216 >/dev/null
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# ╔════════════════════════════════════════════════════════════════╗
print_section "SYSTEMD SERVICE"
cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZIVPN UDP VPN Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable zivpn
systemctl start zivpn

# ╔════════════════════════════════════════════════════════════════╗
print_section "IPTABLES FIX"
iface=$(ip route | awk '/default/ {print $5; exit}')

iptables -t nat -C PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to :5667 2>/dev/null || \
iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to :5667

iptables -t nat -C POSTROUTING -p udp --dport 5667 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -p udp --dport 5667 -j MASQUERADE

iptables-save > /etc/iptables/rules.v4

# ╔════════════════════════════════════════════════════════════════╗
print_section "INSTALL MENU"
wget -q https://raw.githubusercontent.com/welwel11/project3/main/panel-udp-zivpn.sh \
-O /usr/local/bin/menu-zivpn
chmod +x /usr/local/bin/menu-zivpn

# ╔════════════════════════════════════════════════════════════════╗
print_section "AUTO MENU LOGIN"
grep -q menu-zivpn /root/.bashrc || cat >> /root/.bashrc <<EOF

if [ -t 1 ]; then
  clear
  menu-zivpn
fi
EOF

# ╔════════════════════════════════════════════════════════════════╗
print_section "SELESAI"
echo -e "${GREEN}ZIVPN UDP BERHASIL DIINSTAL${RESET}"
echo -e "${CYAN}✔ Jalankan menu: menu-zivpn${RESET}"