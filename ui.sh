#!/bin/bash
# ============================================================
#  nvpanel  ·  bibliothèque d'interface partagée (ui.sh)
#  Chargée par tous les menus :  source /etc/nvpanel/lib/ui.sh
# ============================================================

# ---- Palette ------------------------------------------------
RED='\033[0;31m';   GRN='\033[0;32m';  YLW='\033[0;33m'
BLU='\033[0;34m';   MAG='\033[0;35m';  CYN='\033[0;36m'
WHT='\033[1;37m';   GRY='\033[0;90m';  NC='\033[0m'
BOLD='\033[1m'

# Largeur des cadres
W=56

# ---- Primitives de dessin -----------------------------------
line()  { printf "${CYN}"; printf '─%.0s' $(seq 1 $W); printf "${NC}\n"; }
top()   { printf "${CYN}╭"; printf '─%.0s' $(seq 1 $W); printf "╮${NC}\n"; }
bot()   { printf "${CYN}╰"; printf '─%.0s' $(seq 1 $W); printf "╯${NC}\n"; }

# Centre un texte dans un cadre de largeur W
center() {
  local txt="$1"; local color="${2:-$WHT}"
  local len=${#txt}
  local pad=$(( (W - len) / 2 ))
  local rpad=$(( W - len - pad ))
  printf "${CYN}│${NC}%*s${color}%s${NC}%*s${CYN}│${NC}\n" "$pad" "" "$txt" "$rpad" ""
}

# Ligne d'option de menu :  entry "01" "SSH & OpenVPN"
entry() {
  printf "  ${GRN}[%s]${NC} %-.30s\n" "$1" "$2"
}

# Bannière du panel
banner() {
  clear
  top
  center "N V P A N E L" "${BOLD}${WHT}"
  center "gestionnaire de comptes VPN" "${GRY}"
  bot
}

# ---- Infos système (en-tête du menu) ------------------------
sysinfo() {
  local os ram_used ram_tot cores ip domain up
  os=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}")
  ram_used=$(free -m | awk '/Mem:/{print $3}')
  ram_tot=$(free -m | awk '/Mem:/{print $2}')
  cores=$(nproc)
  ip=$(cat /etc/nvpanel/ip 2>/dev/null || echo "-")
  domain=$(cat /etc/nvpanel/domain 2>/dev/null || echo "non configuré")
  up=$(uptime -p 2>/dev/null | sed 's/up //')

  printf " ${GRY}OS     :${NC} %-22s ${GRY}RAM  :${NC} %s/%s Mo\n" "$os" "$ram_used" "$ram_tot"
  printf " ${GRY}IP     :${NC} %-22s ${GRY}Core :${NC} %s\n" "$ip" "$cores"
  printf " ${GRY}Domaine:${NC} %-22s ${GRY}Up   :${NC} %s\n" "$domain" "${up:-.}"
}

# Compteurs de clients par service
clientcount() {
  local ssh vm vl tr ss
  ssh=$(awk -F: '$3>=1000 && $3<60000 {c++} END{print c+0}' /etc/passwd)
  vm=$(grep -c '^### ' /etc/nvpanel/db/vmess 2>/dev/null || echo 0)
  vl=$(grep -c '^### ' /etc/nvpanel/db/vless 2>/dev/null || echo 0)
  tr=$(grep -c '^### ' /etc/nvpanel/db/trojan 2>/dev/null || echo 0)
  ss=$(grep -c '^### ' /etc/nvpanel/db/shadowsocks 2>/dev/null || echo 0)
  printf " ${GRY}Clients:${NC} SSH ${GRN}%s${NC} · Vmess ${GRN}%s${NC} · Vless ${GRN}%s${NC} · Trojan ${GRN}%s${NC} · SS ${GRN}%s${NC}\n" \
    "$ssh" "$vm" "$vl" "$tr" "$ss"
}

# Petites aides d'affichage
ok()   { printf "${GRN}✔${NC} %s\n" "$1"; }
err()  { printf "${RED}✘${NC} %s\n" "$1"; }
warn() { printf "${YLW}!${NC} %s\n" "$1"; }
pause(){ echo; read -rp "$(printf "${GRY}Entrée pour revenir au menu…${NC}")" _; }
