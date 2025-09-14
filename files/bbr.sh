#!/bin/bash
# =====================================================
# Script Install & Optimize TCP BBR (Support Ubuntu 22+)
# =====================================================

red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'
clear

echo -e "${green}Installing TCP BBR and optimizing system parameters...${NC}"
sleep 2

# Marker supaya tidak install ulang
touch /usr/local/sbin/bbr

# ---------- Helper Function ----------
Add_To_New_Line(){
    if [ "$(tail -n1 $1 | wc -l)" == "0"  ]; then
        echo "" >> "$1"
    fi
    echo "$2" >> "$1"
}

Check_And_Add_Line(){
    if ! grep -q "$2" "$1"; then
        Add_To_New_Line "$1" "$2"
    fi
}

# ---------- Install BBR ----------
Install_BBR(){
    echo -e "\e[32;1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[32;1mInstalling TCP BBR...\e[0m"

    # Cek apakah sudah aktif
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then
        echo -e "\e[0;32mTCP BBR already active!\e[0m"
        echo -e "\e[32;1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
        return
    fi

    # Load modul tcp_bbr (jika ada)
    if modprobe -n tcp_bbr 2>/dev/null; then
        modprobe tcp_bbr
        Check_And_Add_Line "/etc/modules-load.d/modules.conf" "tcp_bbr"
    fi

    # Tambahkan sysctl
    Check_And_Add_Line "/etc/sysctl.conf" "net.core.default_qdisc = fq"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_congestion_control = bbr"

    sysctl -p >/dev/null 2>&1

    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        echo -e "\e[0;32mTCP BBR installed & active!\e[0m"
    else
        echo -e "\e[1;31mFailed to enable BBR!\e[0m"
    fi
    echo -e "\e[32;1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
}

# ---------- Optimize Kernel Parameters ----------
Optimize_Parameters(){
    echo -e "\e[32;1mOptimizing system parameters...\e[0m"

    # File limit
    Check_And_Add_Line "/etc/security/limits.conf" "* soft nofile 65535"
    Check_And_Add_Line "/etc/security/limits.conf" "* hard nofile 65535"
    Check_And_Add_Line "/etc/security/limits.conf" "root soft nofile 51200"
    Check_And_Add_Line "/etc/security/limits.conf" "root hard nofile 51200"

    # IPv4 & IPv6 forwarding
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.ip_forward = 1"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv6.conf.all.forwarding = 1"

    # Optimasi jaringan
    Check_And_Add_Line "/etc/sysctl.conf" "net.core.somaxconn = 10000"
    Check_And_Add_Line "/etc/sysctl.conf" "net.core.rmem_max = 67108864"
    Check_And_Add_Line "/etc/sysctl.conf" "net.core.wmem_max = 67108864"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_fin_timeout = 15"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_tw_reuse = 1"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_max_syn_backlog = 262144"
    Check_And_Add_Line "/etc/sysctl.conf" "net.netfilter.nf_conntrack_max = 262144"

    # Disable ICMP redirect
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.conf.all.accept_redirects = 0"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.conf.default.accept_redirects = 0"

    # Systemd optimization
    Check_And_Add_Line "/etc/systemd/system.conf" "DefaultTimeoutStopSec=30s"
    Check_And_Add_Line "/etc/systemd/system.conf" "DefaultLimitCORE=infinity"
    Check_And_Add_Line "/etc/systemd/system.conf" "DefaultLimitNOFILE=65535"

    sysctl -p >/dev/null 2>&1
    echo -e "\e[0;32mSystem parameters optimized.\e[0m"
}

# ---------- Run ----------
Install_BBR
Optimize_Parameters

echo -e '\e[32;1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m'
echo -e '\e[0;32m       Installation Success!       \e[0m'
echo -e '\e[32;1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m'