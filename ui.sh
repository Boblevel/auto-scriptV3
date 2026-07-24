#!/bin/bash
# ============================================================
#  RHAFF SERVICE · bibliothèque d'interface partagée (ui.sh)
#  source /etc/nvpanel/lib/ui.sh
# ============================================================

# ---- Identité / marque -------------------------------------
# Une locale UTF-8 est nécessaire pour que les accents et les emojis comptent
# pour un seul caractère : sans elle, les cadres se décalent d'un cran.
if [ -z "${LC_ALL:-}" ] && locale -a 2>/dev/null | grep -qiE '^C\.(UTF-8|utf8)$'; then
  export LC_ALL=C.UTF-8
fi

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
    printf "  ${GRN}[%s]${NC} %s %s\n" "$1" "$2" "$3"
  else
    printf "  ${GRN}[%s]${NC} %s\n" "$1" "$2"
  fi
}

# Vide les touches restées en attente dans le terminal.
# Sans ça, les touches tapées pendant une opération longue (mise à jour,
# test de vitesse...) ressortent ensuite dans la saisie sous forme de ^[[A.
flush_in(){
  [ -t 0 ] || return 0
  local _j
  while IFS= read -r -s -t 0.01 -n 512 _j 2>/dev/null; do :; done
  return 0
}

banner() {
  flush_in
  printf '\033[H\033[2J\033[3J'
  top
  center "R H A F F   S E R V I C E" "${BOLD}${WHT}"
  center "panel de gestion & contrôle" "${GRY}"
  center "Telegram : $CONTACT" "${CYN}"
  bot
}

# ---- Aides consommation (compteur clients) -----------------
_iface(){ ip route 2>/dev/null | awk '/default/{print $5; exit}'; }
_hr(){ awk -v b="${1:-0}" 'BEGIN{ if(b=="null"||b==""){b=0}; split("o Ko Mo Go To Po",u," "); i=1; while(b>=1024 && i<6){b/=1024;i++} printf "%.1f %s", b, u[i] }'; }

# renvoie "hier|aujourdhui|mois" en octets (ou 0 si indispo)
_conso_raw(){
  # Consommation des CLIENTS uniquement. Aucun repli sur vnstat :
  # vnstat mesure tout le trafic de la machine (mises à jour, sauvegardes,
  # trafic de l'hébergeur…) et affichait des dizaines de Go jamais consommés
  # par un client VPN.
  local r
  if [ -x /usr/local/bin/nvpanel-conso ]; then
    r=$(/usr/local/bin/nvpanel-conso read 2>/dev/null)
    case "$r" in *'|'*'|'*) echo "$r"; return ;; esac
  fi
  echo "0|0|0"
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

# Tableau de bord d'un protocole précis (affiché en en-tête de son menu)
#   $1 = fichier DB sous /etc/nvpanel/db/   ·   $2 = mode online : ssh | port:PORT | wg
proto_dash() {
  local dbf="$1" mode="$2" total online blocked hier auj mois
  total=$(grep -c '^### ' "/etc/nvpanel/db/$dbf" 2>/dev/null); total=${total:-0}
  online=0; blocked=0
  case "$mode" in
    ssh)
      online=$(ps -eo user,comm 2>/dev/null | awk '$2 ~ /sshd|dropbear/{print $1}' | sort -u | while read -r pu; do
                 uid=$(id -u "$pu" 2>/dev/null)
                 [ -n "$uid" ] && [ "$uid" -ge 1000 ] && [ "$uid" -lt 60000 ] && echo 1
               done | wc -l)
      if [ -f "/etc/nvpanel/db/$dbf" ]; then
        while read -r _ u _; do
          [ -z "$u" ] && continue
          local st; st=$(passwd -S "$u" 2>/dev/null | awk '{print $2}')
          [ "$st" = "L" ] && blocked=$((blocked+1))
        done < "/etc/nvpanel/db/$dbf"
      fi ;;
    port:*)
      local p="${mode#port:}"
      online=$(ss -tnH state established "( sport = :$p )" 2>/dev/null | wc -l) ;;
    wg)
      online=$(wg show wg0 latest-handshakes 2>/dev/null | awk -v n="$(date +%s)" '$2>0 && (n-$2)<180{c++} END{print c+0}') ;;
    ppp:*)
      local pp="${mode#ppp:}"
      online=$(nvpanel-ppp online "$pp" 2>/dev/null); online=${online:-0}
      blocked=$(awk -v d="$(date +%F)" '/^### /{ if ($4!="" && $4<d) c++ } END{print c+0}' "/etc/nvpanel/db/$dbf" 2>/dev/null) ;;
  esac
  IFS='|' read -r hier auj mois <<< "$(_conso_raw)"
  printf " ${GRY}📦 Comptes:${NC} ${WHT}%s${NC}   ${GRY}👥 En ligne:${NC} ${GRN}%s${NC}   ${GRY}⛔ Bloqué:${NC} ${RED}%s${NC}\n" "$total" "$online" "$blocked"
  printf " ${GRY}📊 Trafic serveur — auj.:${NC} %s ${GRY}· mois:${NC} %s\n" "$(_hr "$auj")" "$(_hr "$mois")"
}

# compat : ancien nom
clientcount(){ stats; }

ok()   { printf "${GRN}✔${NC} %s\n" "$1"; }
err()  { printf "${RED}✘${NC} %s\n" "$1"; }
warn() { printf "${YLW}!${NC} %s\n" "$1"; }
pause(){ echo; ask "$(printf "${GRY}Entrée pour revenir au menu…${NC}")" _pausevar; }
# réponse affirmative, insensible à la casse (o/O/oui/OUI/y/yes)
confirm(){ case "${1,,}" in o|oui|y|yes) return 0;; *) return 1;; esac; }

# Écran alterné : le panel s'affiche dans un buffer séparé (comme htop/vim),
# ce qui empêche TOUTE accumulation de bannières dans l'historique du terminal.
# En sortie, l'écran d'origine est restauré proprement.

# Saisie protégée : les flèches / le défilement de l'écran envoient des
# séquences d'échappement (^[[A, ^[[B...). On les avale au lieu de les écrire
# dans la réponse.  Usage : ask "invite" nom_de_variable
ask(){
  local __v="$2" buf="" ch
  [ -n "$1" ] && printf '%b' "$1"
  if [ ! -t 0 ]; then IFS= read -r buf; printf -v "$__v" '%s' "$buf"; return 0; fi
  while IFS= read -rsn1 ch 2>/dev/null; do
    case "$ch" in
      '')       break ;;                                  # Entrée
      $'\e')    # séquence d'échappement : on l'avale jusqu'à son caractère final
                local e=''
                read -rsn1 -t 0.05 e 2>/dev/null || continue
                if [ "$e" = '[' ] || [ "$e" = 'O' ]; then
                  while read -rsn1 -t 0.05 e 2>/dev/null; do
                    case "$e" in [A-Za-z~]) break ;; esac
                  done
                fi
                continue ;;
      $'\177'|$'\b')
                [ -n "$buf" ] && { buf="${buf%?}"; printf '\b \b'; }; continue ;;
      $'\t')    continue ;;
      *)        buf="$buf$ch"; printf '%s' "$ch" ;;
    esac
  done
  printf '\n'
  printf -v "$__v" '%s' "$buf"
  return 0
}


# Durée de connexion d'un compte SSH : on prend le processus le plus ancien
# appartenant au compte (sa session). Renvoie une chaîne vide s'il est hors ligne.
_conn_time(){
  local u="$1" et
  [ -z "$u" ] && return 0
  et=$(ps -o etimes= -u "$u" 2>/dev/null | tr -d ' ' | sort -rn | head -1)
  [ -z "$et" ] && return 0
  [ "$et" -lt 5 ] 2>/dev/null && return 0
  if   [ "$et" -ge 86400 ] 2>/dev/null; then printf '%dj %dh' $((et/86400)) $(((et%86400)/3600))
  elif [ "$et" -ge 3600 ]  2>/dev/null; then printf '%dh %02dmin' $((et/3600)) $(((et%3600)/60))
  else printf '%dmin' $((et/60)); fi
}

# Durée depuis la dernière poignée de main WireGuard (= client actif).
_wg_time(){
  local pub="$1" hs now d
  [ -z "$pub" ] && return 0
  hs=$(wg show wg0 latest-handshakes 2>/dev/null | awk -v p="$pub" '$1==p{print $2}')
  [ -z "$hs" ] || [ "$hs" = 0 ] && return 0
  now=$(date +%s); d=$(( now - hs ))
  [ "$d" -gt 180 ] 2>/dev/null && return 0
  if   [ "$d" -ge 3600 ] 2>/dev/null; then printf '%dh %02dmin' $((d/3600)) $(((d%3600)/60))
  else printf '%dmin' $((d/60)); fi
}

# L'écran alterné n'est PAS empilable : si un sous-menu le quitte, le menu
# parent se remet à écrire dans l'écran normal, dont l'historique accumule
# les cadres. Seul le processus qui l'a ouvert a donc le droit de le fermer.
ui_enter(){
  if [ -z "${NVPANEL_UI:-}" ]; then
    export NVPANEL_UI=$$
    printf '\033[?1049h\033[?1007l\033[?1000l\033[H'
  fi
}
ui_leave(){
  [ "${NVPANEL_UI:-}" = "$$" ] || return 0
  printf '\033[?1007h\033[?1049l'
}

# animation de chargement stylée avec pourcentage (comme l'installation)
loading(){
  local msg="${1:-Chargement}" w=28 i p
  printf '\033[3J\033[H\033[2J'; echo; echo
  for ((p=0;p<=100;p+=4)); do
    i=$(( p*w/100 ))
    printf "\r   ${MAG}%s${NC}  ${CYN}[" "$msg"
    printf "${GRN}%s${NC}" "$(printf '▰%.0s' $(seq 1 "$i" 2>/dev/null))"
    printf "${GRY}%s${NC}" "$(printf '▱%.0s' $(seq 1 $((w-i)) 2>/dev/null))"
    printf "${CYN}]${NC} ${WHT}%3d%%${NC}" "$p"
    sleep 0.012
  done
  printf "\n"
}
