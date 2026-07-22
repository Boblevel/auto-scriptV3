#!/bin/bash
# ============================================================
#  RHAFF SERVICE · installateur
#  Usage :  bash <(curl -fsSL https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main/setup.sh)
# ============================================================

# >>> À PERSONNALISER : ton dépôt GitHub <<<
REPO_RAW="https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main"

BRAND="RHAFF SERVICE"
CONTACT="t.me/bigrhaff226"

RED='\033[0;31m'; GRN='\033[0;32m'; CYN='\033[0;36m'; YLW='\033[0;33m'; WHT='\033[1;37m'; GRY='\033[0;90m'; NC='\033[0m'
say(){ printf "${CYN}➜${NC} %s\n" "$1"; }
die(){ printf "${RED}✘ %s${NC}\n" "$1"; exit 1; }

# --- Vérifications ------------------------------------------
[ "$EUID" -ne 0 ] && die "Ce script doit être lancé en root (sudo su -)."
[ "$(systemd-detect-virt 2>/dev/null)" = "openvz" ] && die "OpenVZ non supporté."
. /etc/os-release 2>/dev/null || die "Distribution inconnue."
if echo "$ID $ID_LIKE" | grep -qiE 'ubuntu|debian'; then
  say "Distribution détectée : $PRETTY_NAME"
else
  die "Ubuntu ou Debian requis (détecté : $PRETTY_NAME)."
fi

# RAM recommandée : 1 Go minimum (non bloquant)
RAM_TOT=$(free -m 2>/dev/null | awk '/Mem:/{print $2}')
if [ -n "$RAM_TOT" ] && [ "$RAM_TOT" -lt 900 ]; then
  printf "${YLW}! RAM détectée : %s Mo — 1 Go minimum recommandé pour de bonnes performances.${NC}\n" "$RAM_TOT"
fi

clear
printf "${CYN}"
cat <<'ART'
   ┌────────────────────────────────────────────────────┐
   │     Installation de  R H A F F   S E R V I C E     │
   └────────────────────────────────────────────────────┘
ART
printf "${NC}\n"

# --- Configuration initiale : domaine + ports ---------------
printf "${CYN}➜ Configuration initiale${NC}\n"
printf "   ${GRY}Ces valeurs sont appliquées par défaut aux protocoles.${NC}\n"
printf "   ${GRY}Rappel : sans TLS = HTTP (port 80) · avec TLS = HTTPS (port 443).${NC}\n"
read -rp "   🌐 Nom de domaine (laisser vide si aucun) : " NVDOMAIN
read -rp "   🔓 Port de connexion SANS TLS / HTTP [80] : " NVPORT
NVPORT=${NVPORT:-80}
[[ "$NVPORT" =~ ^[0-9]+$ ]] || NVPORT=80
echo
printf "   ${GRN}✔ Domaine : %s${NC}\n" "${NVDOMAIN:-aucun}"
printf "   ${GRN}✔ Port sans TLS : %s   ·   Port avec TLS : 443${NC}\n\n" "$NVPORT"

# --- DNS de secours -----------------------------------------
say "Correction DNS…"
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# --- Dépendances --------------------------------------------
say "Mise à jour et installation des dépendances…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null 2>&1
apt-get install -y curl wget jq unzip cron screen socat python3 openssl \
    net-tools dropbear stunnel4 fail2ban vnstat iptables nginx certbot >/dev/null 2>&1

# --- Arborescence -------------------------------------------
say "Déploiement du panel…"
mkdir -p /etc/nvpanel/lib /etc/nvpanel/db

curl -s ipv4.icanhazip.com > /etc/nvpanel/ip 2>/dev/null || curl -s ifconfig.me > /etc/nvpanel/ip 2>/dev/null
[ -n "$NVDOMAIN" ] && echo "$NVDOMAIN" > /etc/nvpanel/domain
echo "$NVPORT" > /etc/nvpanel/xport

# --- Téléchargement robuste : ne s'arrête pas si un fichier manque ---
FAILED=""
fetch(){
  local name dest="$2" done=0
  for name in "$1" "$1.txt"; do
    if curl -fsSL "$REPO_RAW/$name" -o "$dest" 2>/dev/null && [ -s "$dest" ] && ! head -c 200 "$dest" | grep -q '404: Not Found'; then
      chmod +x "$dest"; done=1; break
    fi
  done
  if [ "$done" = 1 ]; then printf "  ${GRN}✔${NC} %s\n" "$1"
  else printf "  ${RED}✘ %s (manquant sur GitHub)${NC}\n" "$1"; FAILED="$FAILED $1"; fi
}
fetch ui.sh            /etc/nvpanel/lib/ui.sh
fetch menu             /usr/local/bin/menu
fetch menu-ssh         /usr/local/bin/menu-ssh
fetch menu-xray        /usr/local/bin/menu-xray
fetch menu-ss          /usr/local/bin/menu-ss
fetch menu-wg          /usr/local/bin/menu-wg
fetch menu-bot         /usr/local/bin/menu-bot
fetch menu-settings    /usr/local/bin/menu-settings
fetch menu-uninstall   /usr/local/bin/menu-uninstall
fetch nvpanel-cli      /usr/local/bin/nvpanel-cli
fetch nvpanel-bot      /usr/local/bin/nvpanel-bot
fetch nvpanel-limit    /usr/local/bin/nvpanel-limit
fetch nvpanel-quota    /usr/local/bin/nvpanel-quota
fetch nvpanel-clean    /usr/local/bin/nvpanel-clean
fetch install-xray     /usr/local/bin/install-xray
fetch install-tls      /usr/local/bin/install-tls
fetch install-slowdns  /usr/local/bin/install-slowdns
fetch install-udp      /usr/local/bin/install-udp
fetch update.sh        /usr/local/bin/update

# Raccourcis : menu = acc = dgh  ·  uninstall
ln -sf /usr/local/bin/menu /usr/local/bin/acc 2>/dev/null
ln -sf /usr/local/bin/menu /usr/local/bin/dgh 2>/dev/null
ln -sf /usr/local/bin/menu-uninstall /usr/local/bin/uninstall 2>/dev/null

# --- Nettoyage auto des comptes expirés ---------------------
say "Configuration du nettoyage automatique…"
( crontab -l 2>/dev/null | grep -v nvpanel-clean; echo "*/10 * * * * /usr/local/bin/nvpanel-clean" ) | crontab - 2>/dev/null

# --- Service limite multi-login -----------------------------
cat > /etc/systemd/system/nvpanel-limit.service <<EOF
[Unit]
Description=RHAFF limite d'appareils
After=network.target
[Service]
ExecStart=/usr/local/bin/nvpanel-limit
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload 2>/dev/null
systemctl enable --now nvpanel-limit >/dev/null 2>&1

# --- Cron quota ---------------------------------------------
( crontab -l 2>/dev/null | grep -v nvpanel-quota; echo "*/5 * * * * /usr/local/bin/nvpanel-quota check" ) | crontab - 2>/dev/null

# --- Installation automatique de Xray (freesurf prêt) -------
if [ -x /usr/local/bin/install-xray ]; then
  say "Préparation des protocoles Xray (freesurf)…"
  /usr/local/bin/install-xray auto 2>/dev/null
fi

# --- SlowDNS : binaire (selon l'archi) + clé FIXE (affichée par défaut) --
say "Préparation de SlowDNS (clé par défaut)…"
mkdir -p /etc/nvpanel/slowdns
case "$(uname -m)" in
  aarch64|arm64) SLDNS_BIN="dns-server-arm64" ;;
  *)             SLDNS_BIN="dns-server" ;;
esac
curl -fsSL "$REPO_RAW/$SLDNS_BIN" -o /etc/nvpanel/slowdns/dns-server 2>/dev/null
curl -fsSL "$REPO_RAW/server.key" -o /etc/nvpanel/slowdns/server.key 2>/dev/null
curl -fsSL "$REPO_RAW/server.pub" -o /etc/nvpanel/slowdns/server.pub 2>/dev/null
chmod +x /etc/nvpanel/slowdns/dns-server 2>/dev/null
if [ ! -s /etc/nvpanel/slowdns/dns-server ]; then
  printf "  ${YLW}! Binaire SlowDNS absent du dépôt (%s) — la clé ne s'affichera pas.${NC}\n" "$SLDNS_BIN"
fi
# Active SlowDNS automatiquement si un domaine a été fourni (NS = ns-<domaine>)
if [ -n "$NVDOMAIN" ] && [ -s /etc/nvpanel/slowdns/dns-server ] && [ -x /usr/local/bin/install-slowdns ]; then
  /usr/local/bin/install-slowdns auto "ns-$NVDOMAIN" 2>/dev/null
fi

# --- Remise à zéro des compteurs de trafic ------------------
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
   │     R H A F F   S E R V I C E   ·   installe !    │
   └──────────────────────────────────────────────────┘
DONE
printf "${NC}\n"
printf "   ${CYN}▶ OUVRIR LE PANEL — tape l'une de ces 3 commandes :${NC}\n"
printf "      ${YLW}menu${NC}   ·   ${YLW}acc${NC}   ·   ${YLW}dgh${NC}\n\n"
printf "   ${CYN}👤 Comptes :${NC}\n"
printf "      ${WHT}menu-ssh${NC}     🔒 SSH / SlowDNS / UDP\n"
printf "      ${WHT}menu-xray vmess|vless|trojan${NC}   🟣 clients Xray\n"
printf "      ${WHT}menu-ss${NC}      🟢 Shadowsocks\n"
printf "      ${WHT}menu-wg${NC}      🛡️ WireGuard\n\n"
printf "   ${CYN}⚙️ Système :${NC}\n"
printf "      ${WHT}menu-settings${NC}   ⚙️ paramètres (domaine, TLS, swap, BBR…)\n"
printf "      ${WHT}menu-bot${NC}        🤖 configurer le bot Telegram\n"
printf "      ${WHT}update${NC}          🔄 mettre à jour\n"
printf "      ${WHT}uninstall${NC}       🗑️ désinstaller le script\n\n"
printf "   ${GRY}🌐 IP : %s   ·   🔓 Port sans TLS : %s   ·   🔒 TLS : 443${NC}\n" "$IPADDR" "$NVPORT"
printf "   ${GRY}📨 Support : %s${NC}\n\n" "$CONTACT"

if [ -n "$FAILED" ]; then
  printf "   ${RED}⚠ Fichiers manquants sur GitHub :${NC}${YLW}%s${NC}\n" "$FAILED"
  printf "   ${GRY}Uploade-les à la racine du dépôt puis relance : update${NC}\n\n"
fi

printf "   ${GRN}➜ Tape ${YLW}menu${GRN} (ou ${YLW}acc${GRN}, ou ${YLW}dgh${GRN}) pour ouvrir le panel.${NC}\n\n"
