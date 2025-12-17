#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                    🧩 ZIVPN - UDP USER PANEL - v1.0                       ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# 📁 Files
CONFIG_FILE="/etc/zivpn/config.json"
USER_DB="/etc/zivpn/users.db"
CONF_FILE="/etc/zivpn.conf"
BACKUP_FILE="/etc/zivpn/config.json.bak"

# 🎨 Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

# 🧽 Clear screen
clear

# 🛠️ Dependencies
command -v jq >/dev/null 2>&1 || { echo -e "${RED}❌ jq is not installed. Use: apt install jq -y${RESET}"; exit 1; }

# 🧠 Create files if they do not exist
mkdir -p /etc/zivpn
[ ! -f "$CONFIG_FILE" ] && echo '{"listen":":5667","cert":"/etc/zivpn/zivpn.crt","key":"/etc/zivpn/zivpn.key","obfs":"zivpn","auth":{"mode":"passwords","config":["zivpn"]}}' > "$CONFIG_FILE"
[ ! -f "$USER_DB" ] && touch "$USER_DB"
[ ! -f "$CONF_FILE" ] && echo 'AUTOCLEAN=OFF' > "$CONF_FILE"

# 🔁 Load configuration
source "$CONF_FILE"

# 📦 Main functions
add_user() {
  echo -e "${CYAN}⚠️  Enter '0' at any time to cancel.${RESET}"

  # Ask for password and validate
  while true; do
    read -p "🔐 Enter new password: " pass

    if [[ "$pass" == "0" ]]; then
      echo -e "${YELLOW}⚠️  Creation cancelled.${RESET}"
      return
    fi

    if [[ -z "$pass" ]]; then
      echo -e "${RED}❌ Password cannot be empty.${RESET}"
      continue
    fi

    if jq -e --arg pw "$pass" '.auth.config | index($pw)' "$CONFIG_FILE" > /dev/null; then
      echo -e "${RED}❌ Password already exists.${RESET}"
      continue
    fi

    break
  done

  # Ask for expiration days
  while true; do
    read -p "📅 Expiration days: " days

    if [[ "$days" == "0" ]]; then
      echo -e "${YELLOW}⚠️  User creation cancelled.${RESET}"
      return
    fi

    if [[ ! "$days" =~ ^[0-9]+$ ]] || [[ "$days" -le 0 ]]; then
      echo -e "${RED}❌ Enter a valid positive number.${RESET}"
      continue
    fi

    break
  done

  exp_date=$(date -d "+$days days" +%Y-%m-%d)

  # Backup before modifying
  cp "$CONFIG_FILE" "$BACKUP_FILE"

  # Add user to JSON config
  jq --arg pw "$pass" '.auth.config += [$pw]' "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"

  # Add user to database
  echo "$pass | $exp_date" >> "$USER_DB"

  echo -e "${GREEN}✅ User added with expiration: $exp_date${RESET}"

  systemctl restart zivpn.service
  read -p "🔙 Press Enter to return to menu..."
}

remove_user() {
  echo -e "${CYAN}🗂️ Current user list:${RESET}"
  list_users

  echo -e "\n🔢 Enter the user ID to delete (0 to cancel)."

  while true; do
    read -p "➡️ Selection: " id

    if [[ "$id" == "0" ]]; then
      echo -e "${YELLOW}⚠️ Deletion cancelled.${RESET}"
      read -p "🔙 Press Enter to return to menu..."
      return
    fi

    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}❌ Enter a valid number or 0 to cancel.${RESET}"
      continue
    fi

    sel_pass=$(sed -n "${id}p" "$USER_DB" | cut -d'|' -f1 | xargs)

    if [[ -z "$sel_pass" ]]; then
      echo -e "${RED}❌ Invalid ID. Try again.${RESET}"
      continue
    fi

    break
  done

  cp "$CONFIG_FILE" "$BACKUP_FILE"

  if jq --arg pw "$sel_pass" '.auth.config -= [$pw]' "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"; then
    sed -i "/^$sel_pass[[:space:]]*|/d" "$USER_DB"
    echo -e "${GREEN}🗑️ User removed successfully.${RESET}"
    systemctl restart zivpn.service
  else
    echo -e "${RED}❌ Error removing user.${RESET}"
  fi

  read -p "🔙 Press Enter to return to menu..."
}

renew_user() {
  list_users

  while true; do
    read -p "🔢 User ID to renew (0 to cancel): " id
    id=$(echo "$id" | xargs)

    if [[ "$id" == "0" ]]; then
      echo -e "${YELLOW}⚠️ Renewal cancelled.${RESET}"
      read -p "🔙 Press Enter to return to menu..."
      return
    fi

    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}❌ Enter a valid number.${RESET}"
      continue
    fi

    sel_pass=$(sed -n "${id}p" "$USER_DB" | cut -d'|' -f1 | xargs)
    [[ -z "$sel_pass" ]] && { echo -e "${RED}❌ Invalid ID.${RESET}"; continue; }
    break
  done

  while true; do
    read -p "📅 Additional days: " days
    [[ "$days" =~ ^[0-9]+$ && "$days" -gt 0 ]] && break
    echo -e "${RED}❌ Enter a valid positive number.${RESET}"
  done

  old_exp=$(sed -n "/^$sel_pass[[:space:]]*|/p" "$USER_DB" | cut -d'|' -f2 | xargs)
  new_exp=$(date -d "$old_exp +$days days" +%Y-%m-%d)

  sed -i "s/^$sel_pass[[:space:]]*|.*/$sel_pass | $new_exp/" "$USER_DB"

  echo -e "${GREEN}🔁 User renewed until: $new_exp${RESET}"
  systemctl restart zivpn.service
  read -p "🔙 Press Enter to return to menu..."
}

list_users() {
  echo -e "\n${CYAN}📋 REGISTERED USERS${RESET}"
  echo -e "${CYAN}╔════╦══════════════════════╦══════════════════╦══════════════════╗${RESET}"
  echo -e "${CYAN}║ ID ║      PASSWORD        ║   EXPIRATION     ║     STATUS       ║${RESET}"
  echo -e "${CYAN}╠════╬══════════════════════╬══════════════════╬══════════════════╣${RESET}"

  i=1
  today=$(date +%Y-%m-%d)
  while IFS='|' read -r pass exp; do
    pass=$(echo "$pass" | xargs)
    exp=$(echo "$exp" | xargs)
    [[ "$exp" < "$today" ]] && status="🔴 EXPIRED" || status="🟢 ACTIVE"
    printf "${CYAN}║ %2s ║ ${YELLOW}%-20s${CYAN} ║ ${YELLOW}%-16s${CYAN} ║ ${YELLOW}%-14s${CYAN}     ║${RESET}\n" "$i" "$pass" "$exp" "$status"
    ((i++))
  done < "$USER_DB"

  echo -e "${CYAN}╚════╩══════════════════════╩══════════════════╩══════════════════╝${RESET}\n"
  [[ "$1" == "true" ]] && read -p "🔙 Press Enter to return to menu..."
}

# 📺 Main menu loop
while true; do
  clear
  [[ "$AUTOCLEAN" == "ON" ]] && clean_expired_users > /dev/null

  IP_PRIVATE=$(hostname -I | awk '{print $1}')
  IP_PUBLIC=$(curl -s ifconfig.me)
  OS_MACHINE=$(grep -oP '^PRETTY_NAME="\K[^"]+' /etc/os-release)
  ARCH=$(uname -m)
  [[ "$ARCH" =~ arm|aarch ]] && ARCH_DISPLAY="ARM" || ARCH_DISPLAY="AMD"

  echo -e "\n${CYAN}╔═════════════════════════════════════════════════════════════════╗"
  echo -e "║                🧩 ZIVPN - UDP USER PANEL                        ║"
  echo -e "╠═════════════════════════════════════════════════════════════════╣"
  echo -e "║ [1] ➕  Create new user (with expiration)                        ║"
  echo -e "║ [2] ❌  Remove user                                              ║"
  echo -e "║ [3] 🗓  Renew user                                               ║"
  echo -e "║ [4] 📋  List users                                               ║"
  echo -e "║ [5] ▶️  Start service                                            ║"
  echo -e "║ [6] 🔁  Restart service                                          ║"
  echo -e "║ [7] ⏹️  Stop service                                             ║"
  echo -e "║ [8] 🧹  Toggle auto-clean expired users                          ║"
  echo -e "║ [9] 🚪  Exit                                                     ║"
  echo -e "╚═════════════════════════════════════════════════════════════════╝${RESET}"

  read -p "📌 Select an option: " opc
  case $opc in
    1) add_user;;
    2) remove_user;;
    3) renew_user;;
    4) list_users true;;
    5) systemctl start zivpn.service;;
    6) systemctl restart zivpn.service;;
    7) systemctl stop zivpn.service;;
    8) toggle_autoclean;;
    9) exit;;
    *) echo -e "${RED}❌ Invalid option.${RESET}";;
  esac
done