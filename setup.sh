#!/bin/bash
# ============================================================
#  RHAFF SERVICE · installateur
#  Usage :  bash <(curl -sL https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main/setup.sh)
# ============================================================
set -e

# >>> À PERSONNALISER : ton dépôt GitHub <<<
REPO_RAW="https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main"

# Marque
BRAND="RHAFF SERVICE"
CONTACT="t.me/bigrhaff226"

RED='\033[0;31m'; GRN='\033[0;32m'; CYN='\033[0;36m'; YLW='\033[0;33m'; WHT='\033[1;37m'; NC='\033[0m'
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
   ┌────────────────────────────────────────────────────┐
   │     Installation de  R H A F F   S E R V I C E     │
   └────────────────────────────────────────────────────┘
ART
printf "${NC}\n"

# --- Configuration initiale : domaine + port V2Ray ----------
printf "${CYN}➜ Configuration initiale${NC}\n"
printf "   ${GRY}Ces valeurs seront appliquées par défaut aux protocoles.${NC}\n"
read -rp "   🌐 Nom de domaine (laisser vide si aucun) : " NVDOMAIN
read -rp "   🔓 Port sans TLS [80] : " NVPORT
NVPORT=${NVPORT:-80}
[[ "$NVPORT" =~ ^[0-9]+$ ]] || NVPORT=80
echo

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

# Domaine + port V2Ray saisis au début
[ -n "$NVDOMAIN" ] && echo "$NVDOMAIN" > /etc/nvpanel/domain
echo "$NVPORT" > /etc/nvpanel/xport

# Téléchargement des composants
fetch(){
  local name dest="$2"
  for name in "$1" "$1.txt"; do
    curl -fsSL "$REPO_RAW/$name" -o "$dest" 2>/dev/null
    if [ -s "$dest" ] && ! head -c 200 "$dest" | grep -q '404: Not Found'; then
      chmod +x "$dest"; return 0
    fi
  done
  die "Fichier introuvable sur GitHub : '$1' (ni '$1.txt'). Vérifie qu'il est à la RACINE du dépôt (branche main)."
}
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
fetch menu-wg          /usr/local/bin/menu-wg
fetch update.sh        /usr/local/bin/update

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

# --- Remise à zéro des compteurs de trafic (le trafic d'install ne compte pas) ---
say "Réinitialisation des compteurs de trafic…"
IFACE=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
if [ -n "$IFACE" ] && command -v vnstat >/dev/null 2>&1; then
  vnstat --remove -i "$IFACE" --force >/dev/null 2>&1
  vnstat --add -i "$IFACE" >/dev/null 2>&1
  systemctl restart vnstat >/dev/null 2>&1
fi

# --- Fin -----------------------------------------------------
IPADDR=$(cat /etc/nvpanel/ip 2>/dev/null)
clear
printf "${GRN}"
cat <<'DONE'
   ┌──────────────────────────────────────────────────┐
   │     R H A F F   S E R V I C E  -  installe !     │
   └──────────────────────────────────────────────────┘
DONE
printf "${NC}\n"
printf "   ${CYN}▶ OUVRIR LE PANEL — tape l'une de ces commandes :${NC}\n"
printf "      ${YLW}menu${NC}   ·   ${YLW}acc${NC}   ·   ${YLW}dgh${NC}\n\n"
printf "   ${CYN}👤 Comptes :${NC}\n"
printf "      ${WHT}menu-ssh${NC}     🔒 SSH / SlowDNS / UDP\n"
printf "      ${WHT}menu-xray vmess|vless|trojan${NC}   🟣 clients Xray\n"
printf "      ${WHT}menu-ss${NC}      🟢 Shadowsocks\n"
printf "      ${WHT}menu-wg${NC}      🛡️ WireGuard\n"
printf "      ${WHT}nvpanel-cli${NC}  ⌨️ gestion en ligne de commande\n\n"
printf "   ${CYN}⚙️ Système :${NC}\n"
printf "      ${WHT}menu-settings${NC}   ⚙️ paramètres (domaine, TLS, swap, BBR…)\n"
printf "      ${WHT}menu-bot${NC}        🤖 configurer le bot Telegram\n"
printf "      ${WHT}update${NC}          🔄 mettre à jour depuis GitHub\n"
printf "      ${WHT}reboot${NC}          🔁 redémarrer le serveur\n"
printf "      ${WHT}uninstall${NC}       🗑️ désinstaller le script\n\n"
printf "   ${CYN}Automatismes :${NC} suppression comptes expirés · limite\n"
printf "   d'appareils · quota de bande passante\n\n"
printf "   ${GRY}🌐 IP du serveur : %s${NC}\n" "$IPADDR"
printf "   ${GRY}📨 Support : %s${NC}\n\n" "$CONTACT"
printf "   ${GRN}➜ Pour ouvrir le panel, tape l'une de ces 3 commandes :${NC}\n"
printf "      ${YLW}menu${NC}   ·   ${YLW}acc${NC}   ·   ${YLW}dgh${NC}\n\n"
