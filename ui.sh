#!/bin/bash
# ============================================================
#  RHAFF SERVICE · bibliothèque d'interface partagée (ui.sh)
#  source /etc/nvpanel/lib/ui.sh
# ============================================================

# ---- Identité / marque -------------------------------------
BRAND="RHAFF SERVICE"
CONTACT="t.me/bigrhaff226"

# ---- Palette ------------------------------------------------
RED='\033[0;31m';   GRN='\033[0;32m';  YLW='\033[0;33m'
BLU='\033[0;34m';   MAG='\033[0;35m';  CYN='\033[0;36m'
WHT='\033[1;37m';   GRY='\033[0;90m';  NC='\033[0m'
BOLD='\033[1m'
W=56

# ---- Primitives de dessin -----------------------------------
line()  { printf "${CYN}"; printf '─%.0s' $(seq 1 $W); printf "${NC}\n"; }
top()   { printf "${CYN}╭"; printf '─%.0s' $(seq 1 $W); printf "╮${NC}\n"; }
bot()   { printf "${CYN}╰"; printf '─%.0s' $(seq 1 $W); printf "╯${NC}\n"; }

center() {
  local txt="$1"; local color="${2:-$WHT}"
  local len=${#txt}
  local pad=$(( (W - len) / 2 ))
  local rpad=$(( W - len - pad ))
  printf "${CYN}│${NC}%*s${color}%s${NC}%*s${CYN}│${NC}\n" "$pad" "" "$txt" "$rpad" ""
}

# Menu : entry "01" "🔒" "Label"  (avec emoji)  ou  entry "1" "Label"
entry() {
  if [ "$#" -ge 3 ]; then
    printf "  ${GRN}[%s]${NC} %s %-.30s\n" "$1" "$2" "$3"
  else
    printf "  ${GRN}[%s]${NC} %-.32s\n" "$1" "$2"
  fi
}

banner() {
  clear
  top
  center "R H A F F   S E R V I C E" "${BOLD}${WHT}"
  center "gestion premium des accès & tunnels" "${GRY}"
  center "$CONTACT" "${CYN}"
  bot
}

# ---- Aides consommation (vnstat) ---------------------------
_iface(){ ip route 2>/dev/null | awk '/default/{print $5; exit}'; }
_hr(){ awk -v b="${1:-0}" 'BEGIN{ if(b=="null"||b==""){b=0}; split("o Ko Mo Go To Po",u," "); i=1; while(b>=1024 && i<6){b/=1024;i++} printf "%.1f %s", b, u[i] }'; }

# renvoie "hier|aujourdhui|mois" en octets (ou 0 si indispo)
_conso_raw(){
  local ifc j jm t y m
  ifc=$(_iface)
  command -v vnstat >/dev/null 2>&1 || { echo "0|0|0"; return; }
  j=$(vnstat -i "$ifc" --json d 2>/dev/null)
  jm=$(vnstat -i "$ifc" --json m 2>/dev/null)
  t=$(echo "$j"  | jq -r '((.interfaces[0].traffic.day[-1].rx // 0)+(.interfaces[0].traffic.day[-1].tx // 0))' 2>/dev/null)
  y=$(echo "$j"  | jq -r '((.interfaces[0].traffic.day[-2].rx // 0)+(.interfaces[0].traffic.day[-2].tx // 0))' 2>/dev/null)
  m=$(echo "$jm" | jq -r '((.interfaces[0].traffic.month[-1].rx // 0)+(.interfaces[0].traffic.month[-1].tx // 0))' 2>/dev/null)
  echo "${y:-0}|${t:-0}|${m:-0}"
}

# ---- En-tête système ---------------------------------------
sysinfo() {
  local os ram_used ram_tot cores ip domain up
  os=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}")
  ram_used=$(free -m | awk '/Mem:/{print $3}')
  ram_tot=$(free -m | awk '/Mem:/{print $2}')
  cores=$(nproc)
  ip=$(cat /etc/nvpanel/ip 2>/dev/null || echo "-")
  domain=$(cat /etc/nvpanel/domain 2>/dev/null || echo "non configuré")
  up=$(uptime -p 2>/dev/null | sed 's/up //; s/ hours\?/h/; s/ minutes\?/m/; s/,//g')
  printf " ${GRY}🖥️  OS   :${NC} %-20s ${GRY}💾 RAM :${NC} %s/%s Mo\n" "${os:0:20}" "$ram_used" "$ram_tot"
  printf " ${GRY}🌐 IP   :${NC} %-20s ${GRY}⚙️  Core:${NC} %s\n" "$ip" "$cores"
  printf " ${GRY}🔗 Dom. :${NC} %-20s ${GRY}⏱️  Up  :${NC} %s\n" "${domain:0:20}" "${up:-.}"
}

# ---- Statistiques comptes ----------------------------------
_count_db(){ grep -c '^### ' "/etc/nvpanel/db/$1" 2>/dev/null || echo 0; }

stats() {
  local ssh online blocked total hier auj mois
  ssh=$(grep -c '^### ' /etc/nvpanel/db/ssh 2>/dev/null); ssh=${ssh:-0}
  online=$(ps -eo user,comm 2>/dev/null | awk '$2 ~ /sshd|dropbear/{print $1}' | sort -u | while read -r pu; do
             uid=$(id -u "$pu" 2>/dev/null)
             [ -n "$uid" ] && [ "$uid" -ge 1000 ] && [ "$uid" -lt 60000 ] && echo 1
           done | wc -l)
  # Bloqué : uniquement les comptes SSH gérés qui sont réellement verrouillés
  blocked=0
  if [ -f /etc/nvpanel/db/ssh ]; then
    while read -r _ u _; do
      [ -z "$u" ] && continue
      local st; st=$(passwd -S "$u" 2>/dev/null | awk '{print $2}')
      [ "$st" = "L" ] && blocked=$((blocked+1))
    done < /etc/nvpanel/db/ssh
  fi
  local vm vl tr ss wg
  vm=$(_count_db vmess); vl=$(_count_db vless); tr=$(_count_db trojan)
  ss=$(_count_db shadowsocks); wg=$(_count_db wireguard)
  total=$(( ssh + vm + vl + tr + ss + wg ))

  IFS='|' read -r hier auj mois <<< "$(_conso_raw)"

  printf " ${GRY}👥 En ligne:${NC} ${GRN}%s${NC}   ${GRY}📦 Total:${NC} ${WHT}%s${NC}   ${GRY}⛔ Bloqué:${NC} ${RED}%s${NC}\n" "$online" "$total" "$blocked"
  printf " ${GRY}📊 Conso — hier:${NC} %s ${GRY}· auj.:${NC} %s ${GRY}· mois:${NC} %s\n" "$(_hr "$hier")" "$(_hr "$auj")" "$(_hr "$mois")"
}

# compat : ancien nom
clientcount(){ stats; }

ok()   { printf "${GRN}✔${NC} %s\n" "$1"; }
err()  { printf "${RED}✘${NC} %s\n" "$1"; }
warn() { printf "${YLW}!${NC} %s\n" "$1"; }
pause(){ echo; read -rp "$(printf "${GRY}Entrée pour revenir au menu…${NC}")" _; }
