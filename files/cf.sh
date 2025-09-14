#!/bin/bash
YELLOW="\033[33m"
GREEN='\e[0;32m'
FONT="\e[0m"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Install dependencies
apt update && apt install jq curl -y

# Bersihkan folder sebelumnya
rm -rf /root/xray/scdomain
mkdir -p /root/xray
clear

echo ""
echo -e "${GREEN} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ${FONT}"
echo -e "${YELLOW}» SETUP DOMAIN CLOUDFLARE ${FONT}"
echo -e "${GREEN} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ${FONT}"
echo ""

# Pilih prefix random
PREFIXES=("vpn" "user" "srv")
PREFIX=${PREFIXES[$RANDOM % ${#PREFIXES[@]}]}

# Generate angka random 2-3 digit
NUM=$(shuf -i 10-999 -n 1)

# Gabungkan menjadi subdomain
DOMAIN=jnstorevpn.biz.id
SUB_DOMAIN="${PREFIX}${NUM}.${DOMAIN}"

# Cloudflare credentials
CF_ID=jonijoni199210@gmail.com
CF_KEY=b3179931dedce6aaad8692d44422639b81921

set -euo pipefail
IP=$(curl -sS ifconfig.me)

echo "Updating DNS for ${SUB_DOMAIN}..."

# Get Zone ID dari Cloudflare
ZONE=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}&status=active" \
-H "X-Auth-Email: ${CF_ID}" \
-H "X-Auth-Key: ${CF_KEY}" \
-H "Content-Type: application/json" | jq -r .result[0].id)

# Check apakah DNS record sudah ada
RECORD=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?name=${SUB_DOMAIN}" \
-H "X-Auth-Email: ${CF_ID}" \
-H "X-Auth-Key: ${CF_KEY}" \
-H "Content-Type: application/json" | jq -r .result[0].id)

# Jika record tidak ditemukan, buat yang baru
if [[ "${#RECORD}" -le 10 ]]; then
    RECORD=$(curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records" \
    -H "X-Auth-Email: ${CF_ID}" \
    -H "X-Auth-Key: ${CF_KEY}" \
    -H "Content-Type: application/json" \
    --data '{"type":"A","name":"'${SUB_DOMAIN}'","content":"'${IP}'","ttl":120,"proxied":false}' | jq -r .result.id)
fi

# Update DNS record jika sudah ada
RESULT=$(curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records/${RECORD}" \
-H "X-Auth-Email: ${CF_ID}" \
-H "X-Auth-Key: ${CF_KEY}" \
-H "Content-Type: application/json" \
--data '{"type":"A","name":"'${SUB_DOMAIN}'","content":"'${IP}'","ttl":120,"proxied":false}')

# Simpan subdomain ke berbagai file konfigurasi
echo "$SUB_DOMAIN" > /root/domain
echo "$SUB_DOMAIN" > /root/scdomain
echo "$SUB_DOMAIN" > /etc/xray/domain
echo "$SUB_DOMAIN" > /etc/v2ray/domain
echo "$SUB_DOMAIN" > /etc/xray/scdomain
echo "IP=$SUB_DOMAIN" > /var/lib/kyt/ipvps.conf

rm -rf cf
sleep 1