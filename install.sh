#!/bin/bash

# Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"
BOLD="\033[1m"
GRAY="\033[1;30m"

print_task() {
  echo -ne "${GRAY}•${RESET} $1..."
}

print_done() {
  echo -e "\r${GREEN}✓${RESET} $1      "
}

print_fail() {
  echo -e "\r${RED}✗${RESET} $1      "
  exit 1
}

run_silent() {
  local msg="$1"
  local cmd="$2"

  print_task "$msg"
  bash -c "$cmd" &>/tmp/zivpn_install.log
  if [ $? -eq 0 ]; then
    print_done "$msg"
  else
    print_fail "$msg (Check /tmp/zivpn_install.log)"
  fi
}

clear
echo -e "${BOLD}ZiVPN UDP Installer${RESET}"
echo -e "${GRAY}VPS Standalone Edition${RESET}"
echo ""

if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
  print_fail "System not supported (Linux AMD64 only)"
fi

if [ -f /usr/local/bin/zivpn ]; then
  echo -e "${YELLOW}! ZiVPN detected. Reinstalling...${RESET}"
  systemctl stop zivpn.service &>/dev/null
  systemctl stop zivpn-api.service &>/dev/null
fi

run_silent "Updating system" "sudo apt-get update"

if ! command -v go &> /dev/null; then
  run_silent "Installing dependencies" "sudo apt-get install -y golang git"
else
  print_done "Dependencies ready"
fi

echo ""
echo -ne "${BOLD}Domain Configuration${RESET}\n"
while true; do
  read -p "Enter Domain: " domain
  if [[ -n "$domain" ]]; then
    break
  fi
done
echo ""

echo -ne "${BOLD}API Key Configuration${RESET}\n"
generated_key=$(openssl rand -hex 16)
echo -e "Generated Key: ${CYAN}$generated_key${RESET}"
read -p "Enter API Key (Press Enter to use generated): " input_key
api_key="${input_key:-$generated_key}"
echo -e "Using Key: ${GREEN}$api_key${RESET}"
echo ""

systemctl stop zivpn.service &>/dev/null

run_silent "Downloading Core" \
"wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn && chmod +x /usr/local/bin/zivpn"

mkdir -p /etc/zivpn
echo "$domain" > /etc/zivpn/domain
echo "$api_key" > /etc/zivpn/apikey
touch /etc/zivpn/users.db

run_silent "Configuring" \
"wget -q https://raw.githubusercontent.com/welwel11/project3/main/config.json -O /etc/zivpn/config.json"

run_silent "Generating SSL" \
"openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj '/C=ID/ST=Jawa Barat/L=Bandung/O=AutoFTbot/OU=IT Department/CN=$domain' -keyout /etc/zivpn/zivpn.key -out /etc/zivpn/zivpn.crt"

cat >> /etc/sysctl.conf <<END
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward=1
fs.file-max=1000000
END
sysctl -p &>/dev/null

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
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /etc/zivpn/api
run_silent "Setting up API" \
"wget -q https://raw.githubusercontent.com/welwel11/project2/main/zivpn-api.go -O /etc/zivpn/api/zivpn-api.go"

cd /etc/zivpn/api
if go build -o zivpn-api zivpn-api.go &>/dev/null; then
  print_done "Compiling API"
else
  print_fail "Compiling API"
fi

cat <<EOF > /etc/systemd/system/zivpn-api.service
[Unit]
Description=ZiVPN Golang API Service
After=network.target zivpn.service

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn/api
ExecStart=/etc/zivpn/api/zivpn-api
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

run_silent "Starting Services" \
"systemctl enable zivpn.service &&
 systemctl start zivpn.service &&
 systemctl enable zivpn-api.service &&
 systemctl start zivpn-api.service"

iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 &>/dev/null
ufw allow 6000:19999/udp &>/dev/null
ufw allow 5667/udp &>/dev/null
ufw allow 8080/tcp &>/dev/null

rm -f "$0" install.tmp install.log &>/dev/null

echo ""
echo -e "${BOLD}Installation Complete${RESET}"
echo -e "Domain  : ${CYAN}$domain${RESET}"
echo -e "API     : ${CYAN}Port 8080${RESET}"
echo -e "Token   : ${CYAN}$api_key${RESET}"
echo ""
echo -e "Untuk membuka menu gunakan: ${GREEN}zivpn-menu${RESET}"


###############################
#  TAMBAHAN: Buat Manager + Autorun
###############################

cat << 'EOF' > /usr/local/bin/zivpn-manager
#!/bin/bash
API="http://127.0.0.1:8080/api"
APIKEY=$(cat /etc/zivpn/apikey)

GREEN="\033[1;32m"
CYAN="\033[1;36m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"
BOLD="\033[1m"

header() {
  clear
  echo -e "${CYAN}=============================="
  echo -e "     ${BOLD}ZiVPN VPS Manager${RESET}${CYAN}"
  echo -e "==============================${RESET}"
}

pause() {
  echo ""
  read -p "Tekan ENTER untuk kembali..."
}

create_user() {
  header
  read -p "Username/Password   : " USERNAME
  read -p "Durasi (hari)       : " DAYS
  read -p "Limit IP (0=all)    : " LIMIT

  curl -s -X POST "$API/user/create" \
    -H "X-API-Key: $APIKEY" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"$USERNAME\",\"days\":$DAYS,\"ip_limit\":$LIMIT}"

  pause
}

delete_user() {
  header
  read -p "Masukkan username/password: " USERNAME

  curl -s -X POST "$API/user/delete" \
    -H "X-API-Key: $APIKEY" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"$USERNAME\"}"

  pause
}

renew_user() {
  header
  read -p "Masukkan username/password: " USERNAME
  read -p "Tambah durasi (hari): " DAYS

  curl -s -X POST "$API/user/renew" \
    -H "X-API-Key: $APIKEY" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"$USERNAME\",\"days\":$DAYS}"

  pause
}

list_users() {
  header
  curl -s -X GET "$API/users" -H "X-API-Key: $APIKEY"
  pause
}

server_info() {
  header
  curl -s -X GET "$API/info" -H "X-API-Key: $APIKEY"
  pause
}

menu() {
  while true; do
    header
    echo -e "1. Buat Akun"
    echo -e "2. Hapus Akun"
    echo -e "3. Perpanjang"
    echo -e "4. List User"
    echo -e "5. Info Server"
    echo -e "0. Exit"
    echo ""
    read -p "Pilih menu: " CH

    case $CH in
      1) create_user ;;
      2) delete_user ;;
      3) renew_user ;;
      4) list_users ;;
      5) server_info ;;
      0) exit ;;
    esac
  done
}

menu
EOF

chmod +x /usr/local/bin/zivpn-manager

echo -e "#!/bin/bash\nzivpn-manager" > /usr/local/bin/zivpn-menu
chmod +x /usr/local/bin/zivpn-menu

echo "zivpn-menu" >> /root/.bash_profile
echo "zivpn-menu" >> /root/.profile