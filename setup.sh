#!/bin/bash
# ============================================================
#  RHAFF SERVICE · installateur
# ============================================================
REPO_RAW="https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main"
BRAND="RHAFF SERVICE"
CONTACT="t.me/bigrhaff226"

RED='\033[0;31m'; GRN='\033[0;32m'; CYN='\033[0;36m'; YLW='\033[0;33m'; WHT='\033[1;37m'; GRY='\033[0;90m'; MAG='\033[0;35m'; NC='\033[0m'
die(){ printf "${RED}✘ %s${NC}\n" "$1"; exit 1; }

# --- Vérifications ------------------------------------------
[ "$EUID" -ne 0 ] && die "Ce script doit être lancé en root (sudo su -)."
[ "$(systemd-detect-virt 2>/dev/null)" = "openvz" ] && die "OpenVZ non supporté."
. /etc/os-release 2>/dev/null || die "Distribution inconnue."
echo "$ID $ID_LIKE" | grep -qiE 'ubuntu|debian' || die "Ubuntu ou Debian requis (détecté : $PRETTY_NAME)."
RAM_TOT=$(free -m 2>/dev/null | awk '/Mem:/{print $2}')

clear
printf "${CYN}"
cat <<'ART'
   ┌────────────────────────────────────────────────────┐
   │        R H A F F   S E R V I C E                     │
   │        Installation                                  │
   └────────────────────────────────────────────────────┘
ART
printf "${NC}\n"
[ -n "$RAM_TOT" ] && [ "$RAM_TOT" -lt 900 ] && printf "${YLW}! RAM %s Mo — 1 Go minimum recommandé.${NC}\n\n" "$RAM_TOT"

# --- Saisies -------------------------------------------------
read -rp "   🌐 Nom de domaine (laisser vide si aucun) : " NVDOMAIN
read -rp "   🔌 Port [443] : " NVPORT
NVPORT=${NVPORT:-443}
[[ "$NVPORT" =~ ^[0-9]+$ ]] || NVPORT=443
echo

# ---- Barre de progression animée ---------------------------
BARW=34; CUR=0
draw(){ # $1 percent  $2 label
  local p=$1 lbl=$2 f=$(( p*BARW/100 )) e i
  e=$(( BARW - f ))
  printf "\r   ${CYN}["
  for ((i=0;i<f;i++)); do printf "${GRN}▰${NC}"; done
  for ((i=0;i<e;i++)); do printf "${GRY}▱${NC}"; done
  printf "${CYN}]${NC} ${WHT}%3d%%${NC}  ${MAG}%-30s${NC}" "$p" "$lbl"
}
fill(){ # $1 target  $2 label
  while [ "$CUR" -lt "$1" ]; do CUR=$((CUR+2)); draw "$CUR" "$2"; sleep 0.015; done
  draw "$CUR" "$2"
}

fill 8 "Préparation du système…"
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

export DEBIAN_FRONTEND=noninteractive
fill 20 "Installation des dépendances…"
apt-get update -y >/dev/null 2>&1
apt-get install -y curl wget jq unzip cron screen socat python3 openssl \
    net-tools dropbear stunnel4 fail2ban vnstat iptables nginx certbot >/dev/null 2>&1

fill 40 "Déploiement du panel…"
mkdir -p /etc/nvpanel/lib /etc/nvpanel/db
curl -s ipv4.icanhazip.com > /etc/nvpanel/ip 2>/dev/null || curl -s ifconfig.me > /etc/nvpanel/ip 2>/dev/null
[ -n "$NVDOMAIN" ] && echo "$NVDOMAIN" > /etc/nvpanel/domain
echo "$NVPORT" > /etc/nvpanel/xport

# Téléchargement SILENCIEUX (détails masqués) — on note juste les manquants
FAILED=""
fetch(){
  local name dest="$2" done=0
  for name in "$1" "$1.txt"; do
    if curl -fsSL "$REPO_RAW/$name" -o "$dest" 2>/dev/null && [ -s "$dest" ] && ! head -c 200 "$dest" | grep -q '404: Not Found'; then
      chmod +x "$dest"; done=1; break
    fi
  done
  [ "$done" = 1 ] || FAILED="$FAILED $1"
}
for pair in \
  "ui.sh:/etc/nvpanel/lib/ui.sh" "menu:/usr/local/bin/menu" "menu-ssh:/usr/local/bin/menu-ssh" \
  "menu-xray:/usr/local/bin/menu-xray" "menu-ss:/usr/local/bin/menu-ss" "menu-wg:/usr/local/bin/menu-wg" \
  "menu-bot:/usr/local/bin/menu-bot" "menu-settings:/usr/local/bin/menu-settings" \
  "menu-uninstall:/usr/local/bin/menu-uninstall" "nvpanel-cli:/usr/local/bin/nvpanel-cli" \
  "nvpanel-bot:/usr/local/bin/nvpanel-bot" "nvpanel-limit:/usr/local/bin/nvpanel-limit" \
  "nvpanel-quota:/usr/local/bin/nvpanel-quota" "nvpanel-clean:/usr/local/bin/nvpanel-clean" \
  "install-xray:/usr/local/bin/install-xray" "install-tls:/usr/local/bin/install-tls" \
  "install-slowdns:/usr/local/bin/install-slowdns" "install-udp:/usr/local/bin/install-udp" \
  "update.sh:/usr/local/bin/update"; do
  fetch "${pair%%:*}" "${pair##*:}"
done
ln -sf /usr/local/bin/menu /usr/local/bin/acc 2>/dev/null
ln -sf /usr/local/bin/menu /usr/local/bin/dgh 2>/dev/null
ln -sf /usr/local/bin/menu-uninstall /usr/local/bin/uninstall 2>/dev/null

fill 62 "Configuration des services…"
( crontab -l 2>/dev/null | grep -v nvpanel-clean; echo "*/10 * * * * /usr/local/bin/nvpanel-clean" ) | crontab - 2>/dev/null
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
( crontab -l 2>/dev/null | grep -v nvpanel-quota; echo "*/5 * * * * /usr/local/bin/nvpanel-quota check" ) | crontab - 2>/dev/null

fill 80 "Préparation des protocoles…"
[ -x /usr/local/bin/install-xray ] && /usr/local/bin/install-xray auto >/dev/null 2>&1

fill 90 "Préparation de SlowDNS…"
mkdir -p /etc/nvpanel/slowdns
case "$(uname -m)" in aarch64|arm64) SLDNS_BIN="dns-server-arm64" ;; *) SLDNS_BIN="dns-server" ;; esac
curl -fsSL "$REPO_RAW/$SLDNS_BIN" -o /etc/nvpanel/slowdns/dns-server 2>/dev/null
curl -fsSL "$REPO_RAW/server.key" -o /etc/nvpanel/slowdns/server.key 2>/dev/null
curl -fsSL "$REPO_RAW/server.pub" -o /etc/nvpanel/slowdns/server.pub 2>/dev/null
chmod +x /etc/nvpanel/slowdns/dns-server 2>/dev/null
if [ -n "$NVDOMAIN" ] && [ -s /etc/nvpanel/slowdns/dns-server ] && [ -x /usr/local/bin/install-slowdns ]; then
  /usr/local/bin/install-slowdns auto "ns-$NVDOMAIN" >/dev/null 2>&1
fi

fill 97 "Finalisation…"
IFACE=$(ip route 2>/dev/null | awk '/default/{print $5; exit}')
if [ -n "$IFACE" ] && command -v vnstat >/dev/null 2>&1; then
  vnstat --remove -i "$IFACE" --force >/dev/null 2>&1
  vnstat --add -i "$IFACE" >/dev/null 2>&1
  systemctl restart vnstat >/dev/null 2>&1
fi
fill 100 "Terminé"
sleep 0.3

# --- Écran final --------------------------------------------
IPADDR=$(cat /etc/nvpanel/ip 2>/dev/null)
clear
printf "${GRN}"
cat <<'DONE'
   ┌──────────────────────────────────────────────────┐
   │                                                    │
   │      ✔   R H A F F   S E R V I C E   installé      │
   │                                                    │
   └──────────────────────────────────────────────────┘
DONE
printf "${NC}\n"
printf "   ${CYN}▶ Pour ouvrir le panel, tape l'une de ces commandes :${NC}\n\n"
printf "         ${WHT}menu${NC}      ${GRY}·${NC}      ${WHT}acc${NC}      ${GRY}·${NC}      ${WHT}dgh${NC}\n\n"
printf "   ${GRY}🌐 IP : %s   ·   📨 Support : %s${NC}\n\n" "$IPADDR" "$CONTACT"
if [ -n "$FAILED" ]; then
  printf "   ${RED}⚠ Fichiers manquants :${NC}${YLW}%s${NC}\n" "$FAILED"
  printf "   ${GRY}Uploade-les sur GitHub puis tape : update${NC}\n\n"
fi
