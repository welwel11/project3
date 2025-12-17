#!/bin/bash

GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

print_section() {
  local title="$1"
  echo -e "${MAGENTA}========================================${RESET}"
  echo -e "${MAGENTA}  $title${RESET}"
  echo -e "${MAGENTA}========================================${RESET}"
}

# ===============================
print_section "CEK INSTALASI"
if [ -f /usr/local/bin/zivpn ] || [ -f /etc/systemd/system/zivpn.service ]; then
  echo -e "${YELLOW}ZIVPN UDP sudah terpasang, dilewati.${RESET}"
  exit 0
fi

# ===============================
print_section "UPDATE SISTEM"
apt update -y && apt upgrade -y

# ===============================
print_section "INSTALL DEPENDENSI"
apt install -y wget curl iptables-persistent openssl

# ===============================
print_section "DOWNLOAD ZIVPN"
wget -q https://github.com/ChristopherAGT/zivpn-tunnel-udp/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 \
-O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

mkdir -p /etc/zivpn
wget -q https://raw.githubusercontent.com/welwel11/project3/main/config.json \
-O /etc/zivpn/config.json

# ===============================
print_section "GENERATE SSL"
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
-subj "/CN=zivpn-udp" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt

# ===============================
print_section "OPTIMASI SISTEM"
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# ===============================
print_section "SYSTEMD SERVICE"
cat >/etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZIVPN UDP Server
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

systemctl daemon-reload
systemctl enable --now zivpn

# ===============================
print_section "IPTABLES FIX"
iface=$(ip route | awk '/default/ {print $5; exit}')

iptables -t nat -C PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to :5667 2>/dev/null || \
iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to :5667

iptables -t nat -C POSTROUTING -p udp --dport 5667 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -p udp --dport 5667 -j MASQUERADE

iptables-save > /etc/iptables/rules.v4

# ===============================
print_section "SELESAI"
echo -e "${GREEN}ZIVPN UDP BERHASIL DIPASANG${RESET}"
echo -e "${CYAN}Cek status : systemctl status zivpn${RESET}"
echo ""
read -rp "ENTER untuk kembali ke VPS..."