#!/bin/bash
# ============================================================
#  nvpanel · installateur
#  Usage :  bash <(curl -sL https://raw.githubusercontent.com/USER/REPO/main/setup.sh)
# ============================================================
set -e

# >>> À PERSONNALISER : ton dépôt GitHub <<<
REPO_RAW="https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main"

RED='\033[0;31m'; GRN='\033[0;32m'; CYN='\033[0;36m'; YLW='\033[0;33m'; NC='\033[0m'
say(){ printf "${CYN}➜${NC} %s\n" "$1"; }
die(){ printf "${RED}✘ %s${NC}\n" "$1"; exit 1; }

# --- Vérifications ------------------------------------------
[ "$EUID" -ne 0 ] && die "Ce script doit être lancé en root."
[ "$(systemd-detect-virt 2>/dev/null)" = "openvz" ] && die "OpenVZ non supporté."

# Distribution : toute version Ubuntu / Debian (et dérivés Debian)
. /etc/os-release 2>/dev/null || die "Distribution inconnue."
if echo "$ID $ID_LIKE" | grep -qiE 'ubuntu|debian'; then
  say "Distribution détectée : $PRETTY_NAME"
else
  die "Ubuntu ou Debian requis (détecté : $PRETTY_NAME)."
fi

clear
printf "${CYN}"
cat <<'ART'
   ┌───────────────────────────────────────────┐
   │        Installation de  N V P A N E L       │
   └───────────────────────────────────────────┘
ART
printf "${NC}\n"

# --- DNS de secours -----------------------------------------
say "Correction DNS…"
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# --- Dépendances --------------------------------------------
say "Mise à jour et installation des dépendances…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null
apt-get install -y curl wget jq unzip cron screen socat python3 openssl \
    net-tools dropbear stunnel4 fail2ban vnstat iptables nginx certbot >/dev/null

# --- Arborescence -------------------------------------------
say "Déploiement du panel…"
mkdir -p /etc/nvpanel/lib /etc/nvpanel/db

# IP publique (mise en cache pour un menu rapide)
curl -s ipv4.icanhazip.com > /etc/nvpanel/ip || curl -s ifconfig.me > /etc/nvpanel/ip

# Téléchargement des composants
fetch(){ curl -sL "$REPO_RAW/$1" -o "$2" && chmod +x "$2"; }
fetch ui.sh            /etc/nvpanel/lib/ui.sh
fetch menu             /usr/local/bin/menu
fetch menu-ssh         /usr/local/bin/menu-ssh
fetch menu-bot         /usr/local/bin/menu-bot
fetch nvpanel-cli      /usr/local/bin/nvpanel-cli
fetch nvpanel-bot      /usr/local/bin/nvpanel-bot
fetch install-slowdns  /usr/local/bin/install-slowdns
fetch install-udp      /usr/local/bin/install-udp
fetch nvpanel-limit    /usr/local/bin/nvpanel-limit
fetch nvpanel-quota    /usr/local/bin/nvpanel-quota
fetch nvpanel-clean    /usr/local/bin/nvpanel-clean
fetch install-xray     /usr/local/bin/install-xray
fetch install-tls      /usr/local/bin/install-tls
fetch menu-xray        /usr/local/bin/menu-xray
fetch menu-ss          /usr/local/bin/menu-ss
fetch menu-settings    /usr/local/bin/menu-settings
fetch menu-uninstall   /usr/local/bin/menu-uninstall

# Raccourcis : menu = acc = dgh  ·  désinstallation = uninstall
ln -sf /usr/local/bin/menu /usr/local/bin/acc
ln -sf /usr/local/bin/menu /usr/local/bin/dgh
ln -sf /usr/local/bin/menu-uninstall /usr/local/bin/uninstall

# --- Tâche : suppression auto des comptes expirés -----------
say "Configuration du nettoyage automatique…"
( crontab -l 2>/dev/null | grep -v nvpanel-clean; echo "*/10 * * * * /usr/local/bin/nvpanel-clean" ) | crontab -

# --- Service : limite d'appareils (multi-login) -------------
say "Activation du contrôle multi-login…"
cat > /etc/systemd/system/nvpanel-limit.service <<EOF
[Unit]
Description=nvpanel limite d'appareils
After=network.target
[Service]
ExecStart=/usr/local/bin/nvpanel-limit
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now nvpanel-limit >/dev/null 2>&1

# --- Cron : quota de bande passante -------------------------
( crontab -l 2>/dev/null | grep -v nvpanel-quota; echo "*/5 * * * * /usr/local/bin/nvpanel-quota check" ) | crontab -

# --- Fin -----------------------------------------------------
IPADDR=$(cat /etc/nvpanel/ip 2>/dev/null)
clear
printf "${GRN}"
cat <<'DONE'
   ┌───────────────────────────────────────────┐
   │      ✔  NVPANEL installé avec succès        │
   └───────────────────────────────────────────┘
DONE
printf "${NC}\n"
printf "   ${CYN}Ouvrir le panel (3 raccourcis identiques) :${NC}\n"
printf "      ${YLW}menu${NC}   ·   ${YLW}acc${NC}   ·   ${YLW}dgh${NC}\n\n"
printf "   ${CYN}Commandes de gestion des comptes :${NC}\n"
printf "      ${WHT}menu-ssh${NC}                gérer SSH / SlowDNS / UDP\n"
printf "      ${WHT}nvpanel-cli create${NC} u p j [lim] [Go]   créer (ligne de commande)\n"
printf "      ${WHT}nvpanel-cli list${NC}        lister les comptes\n"
printf "      ${WHT}nvpanel-cli delete${NC} u    supprimer\n"
printf "      ${WHT}nvpanel-cli lock/unlock${NC} u   (dé)verrouiller\n"
printf "      ${WHT}nvpanel-cli renew${NC} u j   prolonger\n\n"
printf "   ${CYN}Services / protocoles :${NC}\n"
printf "      ${WHT}install-xray${NC}            installer le cœur Xray\n"
printf "      ${WHT}menu-xray vmess|vless|trojan${NC}   gérer les clients Xray\n"
printf "      ${WHT}menu-ss${NC}                 gérer Shadowsocks\n"
printf "      ${WHT}menu-settings${NC}           domaine + activer le TLS (HTTPS)\n"
printf "      ${WHT}install-slowdns${NC}         installer SlowDNS\n"
printf "      ${WHT}install-udp${NC}             installer l'UDP (badvpn/udp-custom)\n"
printf "      ${WHT}nvpanel-cli status${NC}      infos serveur\n"
printf "      ${WHT}journalctl -u nvpanel-bot -f${NC}   logs du bot\n\n"
printf "   ${CYN}Bot Telegram :${NC}\n"
printf "      ${WHT}menu-bot${NC}                configurer token + ID puis activer\n\n"
printf "   ${CYN}Désinstallation complète :${NC}\n"
printf "      ${WHT}uninstall${NC}   (ou ${WHT}menu-uninstall${NC})\n\n"
printf "   ${CYN}Automatismes actifs :${NC} suppression comptes expirés (SSH +\n"
printf "   Xray) · limite d'appareils · quota de bande passante\n\n"
printf "   ${GRY}IP du serveur : %s${NC}\n\n" "$IPADDR"
printf "   ➜ Tape ${YLW}menu${NC} pour commencer.\n\n"
