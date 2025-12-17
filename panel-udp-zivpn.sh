#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                    ZIVPN - PANEL PENGGUNA UDP                 ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# Berkas
CONFIG_FILE="/etc/zivpn/config.json"
USER_DB="/etc/zivpn/users.db"
CONF_FILE="/etc/zivpn.conf"
BACKUP_FILE="/etc/zivpn/config.json.bak"

# Warna
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Bersihkan layar
clear

# Dependensi
command -v jq >/dev/null 2>&1 || { echo -e "${RED}jq belum terinstal. Gunakan: apt install jq -y${RESET}"; exit 1; }

# Membuat berkas jika belum ada
mkdir -p /etc/zivpn
[ ! -f "$CONFIG_FILE" ] && echo '{"listen":":5667","cert":"/etc/zivpn/zivpn.crt","key":"/etc/zivpn/zivpn.key","obfs":"zivpn","auth":{"mode":"passwords","config":["zivpn"]}}' > "$CONFIG_FILE"
[ ! -f "$USER_DB" ] && touch "$USER_DB"
[ ! -f "$CONF_FILE" ] && echo 'AUTOCLEAN=OFF' > "$CONF_FILE"

# Memuat konfigurasi
source "$CONF_FILE"

# Fungsi utama
add_user() {
  echo -e "${CYAN}Masukkan '0' kapan saja untuk membatalkan.${RESET}"

  # Meminta kata sandi dan memastikan tidak kosong serta belum digunakan
  while true; do
    read -p "Masukkan kata sandi baru: " pass

    if [[ "$pass" == "0" ]]; then
      echo -e "${YELLOW}Pembuatan dibatalkan.${RESET}"
      return
    fi

    if [[ -z "$pass" ]]; then
      echo -e "${RED}Kata sandi tidak boleh kosong.${RESET}"
      continue
    fi

    if jq -e --arg pw "$pass" '.auth.config | index($pw)' "$CONFIG_FILE" > /dev/null; then
      echo -e "${RED}Kata sandi sudah ada.${RESET}"
      continue
    fi

    break
  done

  # Solicitar días de expiración y validar que sea número positivo
  while true; do
    read -p "📅 Días de expiración: " days

    if [[ "$days" == "0" ]]; then
      echo -e "${YELLOW}⚠️  Creación de usuario cancelada.${RESET}"
      return
    fi

    if [[ ! "$days" =~ ^[0-9]+$ ]] || [[ "$days" -le 0 ]]; then
      echo -e "${RED}Meminta jumlah hari kedaluwarsa dan memastikan berupa angka positif.${RESET}"
      continue
    fi

    break
  done

  exp_date=$(date -d "+$days days" +%Y-%m-%d)

  # Membuat cadangan sebelum melakukan perubahan
  cp "$CONFIG_FILE" "$BACKUP_FILE"

  # Menambahkan pengguna ke konfigurasi JSON
  jq --arg pw "$pass" '.auth.config += [$pw]' "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"

  # Menambahkan pengguna ke basis data dengan format seragam
  echo "$pass | $exp_date" >> "$USER_DB"

  echo -e "${GREEN}Pengguna berhasil ditambahkan dengan masa berlaku: $exp_date${RESET}"

  # Memulai ulang layanan untuk menerapkan perubahan
  systemctl restart zivpn.service

  # 🛑 Pausar para mostrar resultado
  read -p "🔙 Presione Enter para volver al menú..."
}

remove_user() {
  echo -e "${CYAN}🗂️ Lista de usuarios actuales:${RESET}"
  list_users
  
  echo -e "\n🔢 Ingrese el ID del usuario a eliminar (0 para cancelar)."
  
  while true; do
    read -p "➡️ Selección: " id
    
    if [[ "$id" == "0" ]]; then
      echo -e "${YELLOW}⚠️ Eliminación cancelada.${RESET}"
      read -p "🔙 Presione Enter para volver al menú..."
      return
    fi
    
    # Validar que sea número y dentro del rango
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}❌ Por favor ingrese un número válido o 0 para cancelar.${RESET}"
      continue
    fi

    sel_pass=$(sed -n "${id}p" "$USER_DB" | cut -d'|' -f1 | xargs)

    if [[ -z "$sel_pass" ]]; then
      echo -e "${RED}❌ ID inválido. Intente de nuevo o presione 0 para cancelar.${RESET}"
      continue
    fi

    break
  done

  cp "$CONFIG_FILE" "$BACKUP_FILE"

  if jq --arg pw "$sel_pass" '.auth.config -= [$pw]' "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"; then
    sed -i "/^$sel_pass[[:space:]]*|/d" "$USER_DB"
    echo -e "${GREEN}🗑️ Usuario eliminado exitosamente.${RESET}"
    systemctl restart zivpn.service
  else
    echo -e "${RED}❌ Error al eliminar usuario. No se realizaron cambios.${RESET}"
  fi

  read -p "🔙 Presione Enter para volver al menú..."
}

renew_user() {
  list_users

  while true; do
    read -p "🔢 ID del usuario a renovar (0 para cancelar): " id
    id=$(echo "$id" | xargs)  # Elimina espacios

    if [[ "$id" == "0" ]]; then
      echo -e "${YELLOW}⚠️ Renovación cancelada.${RESET}"
      read -p "🔙 Presione Enter para volver al menú..."
      return
    fi

    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}❌ Por favor ingrese un número válido.${RESET}"
      continue
    fi

    sel_pass=$(sed -n "${id}p" "$USER_DB" | cut -d'|' -f1 | xargs)

    if [[ -z "$sel_pass" ]]; then
      echo -e "${RED}❌ ID inválido o no existe. Intente de nuevo o presione 0 para cancelar.${RESET}"
      continue
    fi

    break
  done

  while true; do
    read -p "📅 Días adicionales: " days
    if [[ ! "$days" =~ ^[0-9]+$ ]] || [[ "$days" -le 0 ]]; then
      echo -e "${RED}❌ Ingrese un número positivo válido.${RESET}"
    else
      break
    fi
  done

  old_exp=$(sed -n "/^$sel_pass[[:space:]]*|/p" "$USER_DB" | cut -d'|' -f2 | xargs)

  if [[ -z "$old_exp" ]]; then
    echo -e "${RED}❌ No se encontró la fecha de expiración para este usuario.${RESET}"
    read -p "🔙 Presione Enter para volver al menú..."
    return
  fi

  new_exp=$(date -d "$old_exp +$days days" +%Y-%m-%d)

  sed -i "s/^$sel_pass[[:space:]]*|.*/$sel_pass | $new_exp/" "$USER_DB"

  echo -e "${GREEN}🔁 Usuario renovado hasta: $new_exp${RESET}"

  systemctl restart zivpn.service

  read -p "🔙 Presione Enter para volver al menú..."
}

list_users() {
  echo -e "\n${CYAN}📋 LISTA DE USUARIOS REGISTRADOS${RESET}"
  echo -e "${CYAN}╔════╦══════════════════════╦══════════════════╦══════════════════╗${RESET}"
  echo -e "${CYAN}║ ID ║     CONTRASEÑA       ║     EXPIRA       ║     ESTADO       ║${RESET}"
  echo -e "${CYAN}╠════╬══════════════════════╬══════════════════╬══════════════════╣${RESET}"

  i=1
  today=$(date +%Y-%m-%d)
  while IFS='|' read -r pass exp; do
    pass=$(echo "$pass" | xargs)
    exp=$(echo "$exp" | xargs)

    if [[ "$exp" < "$today" ]]; then
      status="🔴 VENCIDO"
    else
      status="🟢 ACTIVO"
    fi

    printf "${CYAN}║ %2s ║ ${YELLOW}%-20s${CYAN} ║ ${YELLOW}%-16s${CYAN} ║ ${YELLOW}%-14s${CYAN}     ║${RESET}\n" "$i" "$pass" "$exp" "$status"
    ((i++))
  done < "$USER_DB"

  echo -e "${CYAN}╚════╩══════════════════════╩══════════════════╩══════════════════╝${RESET}\n"
  # Solo mostrar pausa si se llama con argumento true
  [[ "$1" == "true" ]] && read -p "🔙 Presione Enter para volver al menú..."
}

clean_expired_users() {
  local today=$(date +%Y-%m-%d)
  local updated=0
  local expired=()

  cp "$CONFIG_FILE" "$BACKUP_FILE"

  while IFS='|' read -r pass exp; do
    pass=$(echo "$pass" | xargs)
    exp=$(echo "$exp" | xargs)
    if [[ "$exp" < "$today" ]]; then
      expired+=("$pass")
    fi
  done < "$USER_DB"

  if [[ ${#expired[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ No hay usuarios expirados para eliminar.${RESET}"
    return
  fi

  # Actualizar config.json eliminando todos los usuarios expirados de una vez
  local jq_filter='.'
  for pw in "${expired[@]}"; do
    jq_filter+=" | del(.auth.config[] | select(. == \"$pw\"))"
  done

  if ! jq "$jq_filter" "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"; then
    echo -e "${RED}❌ Error al actualizar $CONFIG_FILE con jq.${RESET}"
    return 1
  fi

  # Eliminar usuarios expirados de USER_DB de forma segura
  local temp_db=$(mktemp)
  grep -v -F -f <(printf '%s\n' "${expired[@]}") "$USER_DB" > "$temp_db" && mv "$temp_db" "$USER_DB"

  for u in "${expired[@]}"; do
    echo -e "${YELLOW}🧹 Usuario expirado eliminado: $u${RESET}"
  done

  systemctl restart zivpn.service
  echo -e "${GREEN}✅ Limpieza finalizada y servicio reiniciado.${RESET}"
}

toggle_autoclean() {
  if [[ "$AUTOCLEAN" == "ON" ]]; then
    echo "AUTOCLEAN=OFF" > "$CONF_FILE"
    AUTOCLEAN=OFF
  else
    echo "AUTOCLEAN=ON" > "$CONF_FILE"
    AUTOCLEAN=ON
  fi
}

# ▶️ Servicio
start_service() {
  if systemctl start zivpn.service; then
    echo -e "${GREEN}▶️ Servicio iniciado.${RESET}"
  else
    echo -e "${RED}❌ Error al iniciar el servicio.${RESET}"
  fi
  read -rp "🔙 Presione Enter para volver al menú..."
}

stop_service() {
  if systemctl stop zivpn.service; then
    echo -e "${RED}⏹️ Servicio detenido.${RESET}"
  else
    echo -e "${RED}❌ Error al detener el servicio.${RESET}"
  fi
  read -rp "🔙 Presione Enter para volver al menú..."
}

restart_service() {
  if systemctl restart zivpn.service; then
    echo -e "${YELLOW}🔁 Servicio reiniciado.${RESET}"
  else
    echo -e "${RED}❌ Error al reiniciar el servicio.${RESET}"
  fi
  read -rp "🔙 Presione Enter para volver al menú..."
}

# 📺 Menú principal
while true; do
  clear  # ✅ Limpia la pantalla en cada iteración del menú

[[ "$AUTOCLEAN" == "ON" ]] && clean_expired_users > /dev/null

# Obtener datos reales
IP_PRIVADA=$(hostname -I | awk '{print $1}')
IP_PUBLICA=$(curl -s ifconfig.me)
OS_MACHINE=$(grep -oP '^PRETTY_NAME="\K[^"]+' /etc/os-release)
ARCH_MACHINE=$(uname -m)
# Normalizar arquitectura para mostrar AMD o ARM
if [[ "$ARCH_MACHINE" =~ "arm" || "$ARCH_MACHINE" =~ "aarch" ]]; then
  ARCH_DISPLAY="ARM"
else
  ARCH_DISPLAY="AMD"
fi
PORT="5667"
PORT_RANGE="6000-19999"

echo -e "\n${CYAN}╔═════════════════════════════════════════════════════════════════╗"
echo -e "║                🧩 ZIVPN - PANEL DE USUARIOS UDP                 ║"
echo -e "╠═════════════════════════════════════════════════════════════════╣"
echo -e "║                         📊 INFORMACIÓN                          ║"
echo -e "╠═════════════════════════════════════════════════════════════════╣"
echo -e "${CYAN}║ 📶 IP Privada:   ${GREEN}${IP_PRIVADA}${CYAN}                                       ║"
echo -e "${CYAN}║ 🌐 IP Pública:   ${GREEN}${IP_PUBLICA}${CYAN}                                 ║"
echo -e "${CYAN}║ 🖥️ OS:          ${GREEN}${OS_MACHINE}${CYAN}                             ║"
echo -e "${CYAN}║ 🧠 Arquitectura: ${GREEN}${ARCH_DISPLAY}${CYAN}                                            ║"
echo -e "${CYAN}║ 📍 Puerto:       ${GREEN}${PORT}${CYAN}                                           ║"
echo -e "${CYAN}║ 🔥 IPTABLES:     ${GREEN}${PORT_RANGE}${CYAN}                                     ║"
echo -e "╠═════════════════════════════════════════════════════════════════╣"
echo -e "║ [1] ➕  Crear nuevo usuario (con expiración)                    ║"
echo -e "║ [2] ❌  Remover usuario                                         ║"
echo -e "║ [3] 🗓  Renovar usuario                                         ║"
echo -e "║ [4] 📋  Información de los usuarios                             ║"
echo -e "║ [5] ▶️  Iniciar servicio                                        ║"
echo -e "║ [6] 🔁  Reiniciar servicio                                      ║"
echo -e "║ [7] ⏹️  Detener servicio                                        ║"
if [[ "$AUTOCLEAN" == "ON" ]]; then
  echo -e "║ [8] 🧹  Eliminar usuarios vencidos            [${GREEN}ON${CYAN}]              ║"
else
  echo -e "║ [8] 🧹  Eliminar usuarios vencidos            [${RED}OFF${CYAN}]             ║"
fi
echo -e "║ [9] 🚪  Salir                                                   ║"
echo -e "╚═════════════════════════════════════════════════════════════════╝${RESET}"

read -p "📌 Seleccione una opción: " opc
case $opc in
  1) add_user;;
  2) remove_user;;
  3) renew_user;;
  4) list_users true;;
  5) start_service;;
  6) restart_service;;
  7) stop_service;;
  8) toggle_autoclean;;
  9) exit;;
  *) echo -e "${RED}❌ Opción inválida.${RESET}";;
esac
done
