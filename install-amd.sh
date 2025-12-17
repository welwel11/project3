#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════╗
# ║        INSTALLER MODUL ZIVPN UDP                                 ║
# ╚════════════════════════════════════════════════════════════════════╝

# Warna untuk presentasi
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

# Fungsi untuk mencetak bagian dengan garis tepi
print_section() {
  local title="$1"
  echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${MAGENTA}║  $title${RESET}$(printf ' %.0s' {1..$(($(tput cols)-${#title}-4))})${MAGENTA}║${RESET}"
  echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${RESET}"
}

# Fungsi untuk menampilkan spinner dan menangani kesalahan
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
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  wait $pid
  local exit_code=$?

  if [ $exit_code -eq 0 ]; then
    echo -e " ${GREEN}✔️${RESET}"
  else
    echo -e " ${RED}❌ Error${RESET}"
    echo -e "${RED}🛑 Terjadi kesalahan saat menjalankan:${RESET} ${YELLOW}$msg${RESET}"
    echo -e "${RED}📄 Detail kesalahan:${RESET}"
    cat /tmp/zivpn_spinner.log
    exit 1
  fi
  rm -f /tmp/zivpn_spinner.log
}

# ╔════════════════════════════════════════════════════════════════╗
print_section "MEMERIKSA INSTALASI ZIVPN UDP SEBELUMNYA"
if [ -f /usr/local/bin/zivpn ] || [ -f /etc/systemd/system/zivpn.service ]; then
  echo -e "${YELLOW}ZIVPN UDP tampaknya sudah terpasang di sistem ini.${RESET}"
  echo -e "${YELLOW}Demi keamanan, proses instalasi akan dihentikan untuk mencegah penimpaan.${RESET}"
  exit 1
fi

# ╔════════════════════════════════════════════════════════════════╗
print_section "MEMPERBARUI SISTEM"
run_with_spinner "Memperbarui paket sistem" "sudo apt-get update && sudo apt-get upgrade -y"

# ╔════════════════════════════════════════════════════════════════╗
print_section "MENGUNDUH ZIVPN UDP"
echo -e "${CYAN}Mengunduh biner ZIVPN...${RESET}"
systemctl stop zivpn.service &>/dev/null
wget -q https://github.com/ChristopherAGT/zivpn-tunnel-udp/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

echo -e "${CYAN}Menyiapkan konfigurasi...${RESET}"
mkdir -p /etc/zivpn
wget -q https://raw.githubusercontent.com/welwel11/project3/main/config.json -O /etc/zivpn/config.json

# ╔════════════════════════════════════════════════════════════════╗
print_section "MEMBUAT SERTIFIKAT SSL"
run_with_spinner "Membuat sertifikat SSL" "openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj '/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn' -keyout /etc/zivpn/zivpn.key -out /etc/zivpn/zivpn.crt"

# ╔════════════════════════════════════════════════════════════════╗
print_section "MENGOPTIMALKAN PARAMETER SISTEM"
sysctl -w net.core.rmem_max=16777216 &>/dev/null
sysctl -w net.core.wmem_max=16777216 &>/dev/null

# ╔════════════════════════════════════════════════════════════════╗
print_section "MEMBUAT LAYANAN SYSTEMD"
if [ -f /etc/systemd/system/zivpn.service ]; then
    echo -e "${YELLOW}Layanan ZIVPN sudah ada. Pembuatan akan dilewati.${RESET}"
else
    echo -e "${CYAN}Mengonfigurasi layanan systemd...${RESET}"
    cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=ZIVPN UDP VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
fi

# ╔════════════════════════════════════════════════════════════════╗
: '
# ╔════════════════════════════════════════════════════════════════╗
# print_section "MENGONFIGURASI KATA SANDI"
# echo -e "${YELLOW}Masukkan kata sandi yang dipisahkan dengan koma (Ej: pass1,pass2)"
# read -p "Kata sandi (bawaan: zivpn): " input_config

# if [ -n "$input_config" ]; then
#     IFS=',' read -r -a config <<< "$input_config"
#     [ ${#config[@]} -eq 1 ] && config+=("${config[0]}")
# else
#     config=("zivpn")
# fi

# new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"
# sed -i -E "s/\"config\": ?.*/${new_config_str}/g" /etc/zivpn/config.json
'

# ╔════════════════════════════════════════════════════════════════╗
print_section "MENJALANKAN DAN MENGAKTIFKAN LAYANAN"
systemctl enable zivpn.service
systemctl start zivpn.service

# ╔════════════════════════════════════════════════════════════════╗
print_section "MENGONFIGURASI IPTABLES DAN FIREWALL"
iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
if ! iptables -t nat -C PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 &>/dev/null; then
    iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
else
    echo -e "${YELLOW}Aturan iptables sudah ada. Melewati penambahan ulang.${RESET}"
fi

ufw allow 6000:19999/udp
ufw allow 5667/udp

# ╔════════════════════════════════════════════════════════════════╗
print_section "MENGINSTAL PANEL PENGELOLAAN"
run_with_spinner "Mengunduh panel pengelolaan (menu-zivpn)" \
"wget -q https://raw.githubusercontent.com/welwel11/project3/main/panel-udp-zivpn.sh \
-O /usr/local/bin/menu-zivpn && chmod +x /usr/local/bin/menu-zivpn"

# ╔════════════════════════════════════════════════════════════════╗
print_section "MENGATUR AUTO MENU SETELAH LOGIN"

# Auto buka menu-zivpn saat login root
if ! grep -q "menu-zivpn" /root/.bashrc 2>/dev/null; then
cat >> /root/.bashrc << 'EOF'

# Auto open ZIVPN menu
if [ -t 1 ]; then
    clear
    menu-zivpn
fi

EOF
fi

# ╔════════════════════════════════════════════════════════════════╗
print_section "SELESAI"
rm -f install-amd.sh install-amd.tmp install-amd.log &>/dev/null
echo -e "${GREEN}ZIVPN UDP berhasil diinstal.${RESET}"
echo -e "${GREEN}Menu akan terbuka otomatis setelah login / reboot.${RESET}"
echo -e "${GREEN}Atau jalankan manual dengan perintah ${CYAN}menu-zivpn${GREEN}.${RESET}"