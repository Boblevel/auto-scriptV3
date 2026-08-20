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
line()  { printf "${CYN}"; printf '━%.0s' $(seq 1 $W); printf "${NC}\n"; }
top()   { printf "${CYN}┏"; printf '━%.0s' $(seq 1 $W); printf "┓${NC}\n"; }
bot()   { printf "${CYN}┗"; printf '━%.0s' $(seq 1 $W); printf "┛${NC}\n"; }

center() {
  local txt="$1"; local color="${2:-$WHT}"
  local len=${#txt}
  local pad=$(( (W - len) / 2 ))
  local rpad=$(( W - len - pad ))
  printf "${CYN}┃${NC}%*s${color}%s${NC}%*s${CYN}┃${NC}\n" "$pad" "" "$txt" "$rpad" ""
}

# Menu : entry "01" "🔒" "Label"  (avec emoji)  ou  entry "1" "Label"
# Regroupe plusieurs entrées courtes sur une seule ligne, pour que le menu
# tienne entièrement sur un écran de téléphone (sinon le cadre du haut sort
# de l'écran et devient invisible).
entry_row() {
  local out="" n e t
  while [ "$#" -ge 3 ]; do
    n="$1"; e="$2"; t="$3"; shift 3
    out+=$(printf "  ${GRN}[%s]${NC} %s %s" "$n" "$e" "$t")
  done
  printf "%b\n" "$out"
}

_upper(){ printf '%s' "$1" | tr 'a-zàâäéèêëîïôöùûüçœ' 'A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇŒ'; }
entry() {
  if [ "$#" -ge 3 ]; then
    printf "  ${GRN}[%s]${NC} %s ${WHT}%s${NC}\n" "$1" "$2" "$(_upper "$3")"
  else
    printf "  ${GRN}[%s]${NC} ${WHT}%s${NC}\n" "$1" "$(_upper "$2")"
  fi
}

# Cadre fermé réutilisable pour les menus protocoles.
# N'ajoute qu'une bordure haute et basse : les options gardent une ligne
# chacune afin de rester sous la limite des terminaux mobiles.
menu_box_top(){ top; }
menu_box_bot(){ bot; }
menu_box_entry(){
  local n="$1" e="$2" t="$3"
  printf "${CYN}┃${NC} ${GRN}[%s]${NC} %s ${WHT}%s${NC}" "$n" "$e" "$(_upper "$t")"
  printf "\033[%dG${CYN}┃${NC}\n" "$((W + 2))"
}

# Tableau fermé : bord cyan, séparateurs internes gris comme sur la maquette.
table_top(){ top; }
table_bot(){ bot; }
table_sep(){
  printf "${CYN}┣${GRY}"; printf '─%.0s' $(seq 1 $W); printf "${CYN}┫${NC}\n"
}
box_sep(){
  printf "${CYN}┣${GRY}"; printf '─%.0s' $(seq 1 $W); printf "${CYN}┫${NC}\n"
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

# Hauteur de l'écran : sur un téléphone (~27 lignes utiles) l'affichage doit
# être resserré, sinon le cadre du haut sort de l'écran et devient invisible.
_rows(){
  local r; r=$(tput lines 2>/dev/null) || r="${LINES:-24}"
  case "$r" in ''|*[!0-9]*) r=24 ;; esac
  printf '%s' "$r"
}

# Niveau d'affichage, calculé sur la hauteur réelle du terminal.
# L'en-tête doit rester visible sur TOUS les téléphones : quand la place
# manque, on retire d'abord les séparateurs, puis on regroupe les entrées.
#   1 = complet (32 lignes)   2 = sans séparateurs (27)   3 = groupé (18)
# L'affichage est VOLONTAIREMENT identique sur tous les téléphones :
# même cadre, même disposition, une commande par ligne. Aucune variante
# selon la hauteur de l'écran.
ui_level(){ printf '1'; }
_small(){ [ "$(ui_level)" != 1 ]; }
# Séparateur affiché uniquement quand la place le permet.
# Séparateur du menu d'accueil : même bleu que le cadre, pour un ensemble
# cohérent. (Il a été rouge un temps, à la demande de l'auteur, puis remis
# en bleu.) `line()` fait exactement le même trait.
sep(){ line; }


# ---- Encadré d'accueil -------------------------------------------------
# Les informations du serveur sont présentées dans un cadre, la marque
# inscrite dans la bordure du haut et le contact dans celle du bas.
# Remplace la bannière séparée du menu d'accueil : deux lignes gagnées et
# un rendu plus net. Les bordures ne portent que du texte simple (pas
# d'emoji), leur largeur est donc calculée de façon fiable.
_edge(){ # $1 = coin gauche, $2 = coin droit, $3 = texte inséré
  local t=" $3 " n l r
  n=${#t}
  [ "$n" -ge "$W" ] && { t=""; n=0; }
  l=$(( (W - n) / 2 ))          # tirets à gauche du texte
  r=$(( W - n - l ))            # tirets à droite : le texte est centré
  printf "${CYN}%s%s%s%s%s${NC}\n" \
    "$1" \
    "$(printf '━%.0s' $(seq 1 "$l" 2>/dev/null))" \
    "$t" \
    "$(printf '━%.0s' $(seq 1 "$r" 2>/dev/null))" \
    "$2"
}


infobox(){
  flush_in
  printf '\033[H\033[2J\033[3J'
  # Accueil compact : marque dans la bordure haute, informations serveur
  # directement dessous, contact dans la bordure basse. Ne pas ajouter de
  # ligne ici : le menu principal doit rester dans la hauteur sûre Termius.
  _edge "┏" "┓" "R H A F F   S E R V I C E"
  sysinfo
  stats
  _edge "┗" "┛" "$CONTACT"
}

banner() {
  flush_in
  # Simple retour en haut + effacement de l'écran.
  # SURTOUT PAS de réinitialisation (\033c) ici : elle ferait quitter
  # l'écran séparé et tout l'intérêt serait perdu.
  printf '\033[H\033[2J'
  top
  center "R H A F F   S E R V I C E" "${BOLD}${WHT}"
  center "panel de gestion & contrôle · $CONTACT" "${GRY}"
  bot
}









# ---- Aides consommation (compteur clients) -----------------
_iface(){ ip route 2>/dev/null | awk '/default/{print $5; exit}'; }
_hr(){ awk -v b="${1:-0}" 'BEGIN{ if(b=="null"||b==""){b=0}; split("o Ko Mo Go To Po",u," "); i=1; while(b>=1024 && i<6){b/=1024;i++} printf "%.1f %s", b, u[i] }'; }

# Affichage uniquement (JJ-MM-AAAA) — les dates restent stockées en AAAA-MM-JJ
# dans toutes les bases (comparaisons de tri comme "$exp < $today" en
# dépendent) : ne jamais utiliser cette fonction pour stocker ou comparer,
# seulement pour l'affichage final à l'écran.
_fmtd(){ [ -n "$1" ] && date -d "$1" +"%d-%m-%Y" 2>/dev/null || printf '%s' "$1"; }

# renvoie "hier|aujourdhui|mois" en octets (ou 0 si indispo)
# renvoie "hier|aujourdhui|mois" en octets (ou 0 si indispo)
# Sans argument : total global (accueil). Avec un argument (ex. "vmess",
# "ssh_bundle") : consommation de ce seul protocole, pour les menus dédiés.
_conso_raw(){
  # Consommation des CLIENTS uniquement. Aucun repli sur vnstat :
  # vnstat mesure tout le trafic de la machine (mises à jour, sauvegardes,
  # trafic de l'hébergeur…) et affichait des dizaines de Go jamais consommés
  # par un client VPN.
  local tag="$1" r
  if [ -x /usr/local/bin/nvpanel-conso ]; then
    if [ -n "$tag" ]; then
      r=$(/usr/local/bin/nvpanel-conso read "$tag" 2>/dev/null)
    else
      r=$(/usr/local/bin/nvpanel-conso read 2>/dev/null)
    fi
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
  printf "${CYN}┃${NC} ${GRY}🖥️  OS   :${NC} %-20s ${GRY}💾 RAM :${NC} %s/%s Mo" "${os:0:20}" "$ram_used" "$ram_tot"; printf "\033[%dG${CYN}┃${NC}\n" "$((W + 2))"
  printf "${CYN}┃${NC} ${GRY}🌐 IP   :${NC} %-20s ${GRY}⚙️  Core:${NC} %s" "$ip" "$cores"; printf "\033[%dG${CYN}┃${NC}\n" "$((W + 2))"
  printf "${CYN}┃${NC} ${GRY}🔗 Dom. :${NC} %-20s ${GRY}⏱️  Up  :${NC} %s" "${domain:0:20}" "${up:-.}"; printf "\033[%dG${CYN}┃${NC}\n" "$((W + 2))"
}

# Compte les CLIENTS RÉELS distincts (par IP source), jamais le nombre brut
# de sockets établis : une application peut ouvrir plusieurs connexions TCP
# en parallèle (multiplexage), et une connexion mal refermée après une
# tentative ratée peut rester des heures en ESTABLISHED. Un simple `wc -l`
# fait alors exploser le chiffre très au-delà du nombre réel de personnes
# connectées (ex. observé : 1 client Vmess réel affiché comme 100+ « en ligne »).
_online_uniq_port() {
  local port="$1"
  ss -tnH state established "( sport = :$port )" 2>/dev/null \
    | awk '{print $4}' | sed -E 's/:[0-9]+$//' | sort -u | wc -l
}

# SSH / SlowDNS / UDP : contrairement au simple « au moins un processus sshd
# appartient à ce compte » (qui ne compte qu'un compte, jamais ses connexions
# multiples), on identifie ICI chaque session établie sur le port SSH ou
# Dropbear via les sockets système (ss), on retrouve le compte réel qui la
# détient (ps, le processus sshd/dropbear tourne sous l'UID du compte après
# authentification), et on ne garde qu'un seul (compte, IP) par couple. Un
# même compte connecté depuis 3 appareils différents compte donc pour 3, et
# non plus pour 1 — comme le nombre réel de personnes connectées.
_ssh_sessions() {
  # On part des PROCESSUS (comme l'ancienne méthode, fiable et déjà éprouvée),
  # jamais de la position des colonnes de « ss » : leur nombre et leur ordre
  # varient selon la version d'iproute2 installée (colonne « Netid » présente
  # ou non), ce qui avait totalement cassé une précédente tentative basée sur
  # $4/$5 (0 connexion détectée alors qu'un compte était bien en ligne).
  # Ici, on ne cherche dans la sortie de « ss » qu'un motif IP:port par
  # expression régulière (jamais une position de colonne) pour retrouver
  # l'IP distante de chaque session — et si elle reste introuvable pour une
  # raison quelconque, le compte est quand même compté une fois : jamais
  # moins fiable que l'ancienne méthode, plus précis quand c'est possible.
  # Renvoie une ligne "compte|ip" par session distincte (dédupliquée) : un
  # seul balayage réseau, réutilisable pour le total ET le détail par compte.
  local ss_raw
  ss_raw=$(ss -tnp state established 2>/dev/null)
  ps -eo pid=,user=,comm= 2>/dev/null | awk '$3 ~ /sshd|dropbear/{print $1"|"$2}' \
    | while IFS='|' read -r pid u; do
        [ -z "$pid" ] || [ -z "$u" ] && continue
        grep -q "^### $u " /etc/nvpanel/db/ssh 2>/dev/null || continue
        ip=$(printf '%s\n' "$ss_raw" | grep "pid=$pid," \
             | grep -oP '[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]+|\[[0-9a-fA-F:]+\]:[0-9]+' \
             | tail -1 | sed -E 's/:[0-9]+$//')
        printf '%s|%s\n' "$u" "${ip:-pid$pid}"
      done | sort -u
}

_ssh_online() { _ssh_sessions | wc -l; }

# Xray (Vmess/Vless/Trojan) : les trois partagent la MÊME façade nginx (un
# seul port TLS, routage par chemin /vmess /vless /trojan). Xray ne reçoit
# ces connexions QUE via la boucle locale : l'adresse vue côté Xray est
# TOUJOURS 127.0.0.1 (nginx lui-même), jamais l'IP du client — impossible
# donc de compter par IP à ce niveau, et impossible de séparer par protocole
# quel que soit le port loopback interrogé (8080/8081/8082). La SEULE IP
# fiable est celle vue par nginx, sur son port PUBLIC. Ce total (clients
# distincts connectés à la façade Xray, tous protocoles confondus) est donc
# le seul chiffre honnête disponible ; il est utilisé pour les 3 protocoles.
_xray_online() {
  local xport; xport=$(cat /etc/nvpanel/xport 2>/dev/null || echo 443)
  _online_uniq_port "$xport"
}

# ---- Statistiques comptes ----------------------------------
# ATTENTION : « grep -c » renvoie un code d'erreur quand le compte est 0,
# tout en affichant « 0 ». Un « || echo 0 » ajouterait donc un SECOND zéro
# (résultat « 0 0 ») qui casse ensuite les calculs. On teste la variable.
_count_db(){ local n; n=$(grep -c '^### ' "/etc/nvpanel/db/$1" 2>/dev/null); printf '%s' "${n:-0}"; }

stats() {
  local online blocked total hier auj mois
  local ssh on_ssh bl_ssh
  ssh=$(grep -c '^### ' /etc/nvpanel/db/ssh 2>/dev/null); ssh=${ssh:-0}
  on_ssh=$(_ssh_online)
  bl_ssh=0
  if [ -f /etc/nvpanel/db/ssh ]; then
    while read -r _ u _; do
      [ -z "$u" ] && continue
      local st; st=$(passwd -S "$u" 2>/dev/null | awk '{print $2}')
      [ "$st" = "L" ] && bl_ssh=$((bl_ssh+1))
    done < /etc/nvpanel/db/ssh
  fi

  local vm vl tr ss wg l2 pp sst hy
  vm=$(_count_db vmess); vl=$(_count_db vless); tr=$(_count_db trojan)
  ss=$(_count_db shadowsocks); wg=$(_count_db wireguard)
  l2=$(_count_db l2tp); pp=$(_count_db pptp); sst=$(_count_db sstp)
  hy=$(_count_db hysteria)
  total=$(( ssh + vm + vl + tr + ss + wg + l2 + pp + sst + hy ))

  local on_xray on_ss on_wg on_l2 on_pp on_sst
  # Ne compte « en ligne » que si des comptes existent pour ce protocole :
  # sinon une connexion quelconque sur le port public (scan internet, très
  # courant sur tout VPS exposé) peut apparaître comme un faux client alors
  # qu'aucun compte n'a jamais été créé.
  on_xray=0
  # Chaque protocole Xray compte désormais ses propres comptes actifs
  # (nvpanel-cli xonline, basé sur l'activité réelle par compte) plutôt
  # qu'un seul total de sockets partagé sur le port public, qui ne pouvait
  # pas distinguer Vmess/Vless/Trojan entre eux.
  [ "$vm" -gt 0 ] && on_xray=$(( on_xray + $(nvpanel-cli xonline vmess 2>/dev/null || echo 0) ))
  [ "$vl" -gt 0 ] && on_xray=$(( on_xray + $(nvpanel-cli xonline vless 2>/dev/null || echo 0) ))
  [ "$tr" -gt 0 ] && on_xray=$(( on_xray + $(nvpanel-cli xonline trojan 2>/dev/null || echo 0) ))
  on_ss=0;   [ "$ss" -gt 0 ] && on_ss=$(_online_uniq_port 8388)
  on_wg=$(wg show wg0 latest-handshakes 2>/dev/null | awk -v n="$(date +%s)" '$2>0 && (n-$2)<180{c++} END{print c+0}')
  on_l2=0;  [ "$l2"  -gt 0 ] && { on_l2=$(nvpanel-ppp online l2tp 2>/dev/null); on_l2=${on_l2:-0}; }
  on_pp=0;  [ "$pp"  -gt 0 ] && { on_pp=$(nvpanel-ppp online pptp 2>/dev/null); on_pp=${on_pp:-0}; }
  on_sst=0; [ "$sst" -gt 0 ] && { on_sst=$(nvpanel-ppp online sstp 2>/dev/null); on_sst=${on_sst:-0}; }
  # Hysteria2 (QUIC) : pas de comptage par session fiable, volontairement
  # exclu plutôt que d'afficher un faux chiffre.
  online=$(( on_ssh + on_xray + on_ss + on_wg + on_l2 + on_pp + on_sst ))

  local bl_vm bl_vl bl_tr bl_ss bl_l2 bl_pp bl_sst
  bl_vm=$(awk '/^### /{if($5=="L")c++} END{print c+0}' /etc/nvpanel/db/vmess 2>/dev/null)
  bl_vl=$(awk '/^### /{if($5=="L")c++} END{print c+0}' /etc/nvpanel/db/vless 2>/dev/null)
  bl_tr=$(awk '/^### /{if($5=="L")c++} END{print c+0}' /etc/nvpanel/db/trojan 2>/dev/null)
  bl_ss=$(awk '/^### /{if($5=="L")c++} END{print c+0}' /etc/nvpanel/db/shadowsocks 2>/dev/null)
  bl_l2=$(awk '/^### /{if($5=="L")c++} END{print c+0}' /etc/nvpanel/db/l2tp 2>/dev/null)
  bl_pp=$(awk '/^### /{if($5=="L")c++} END{print c+0}' /etc/nvpanel/db/pptp 2>/dev/null)
  bl_sst=$(awk '/^### /{if($5=="L")c++} END{print c+0}' /etc/nvpanel/db/sstp 2>/dev/null)
  blocked=$(( bl_ssh + bl_vm + bl_vl + bl_tr + bl_ss + bl_l2 + bl_pp + bl_sst ))

  IFS='|' read -r hier auj mois <<< "$(_conso_raw)"

  printf "${CYN}┃${NC} ${GRY}👥 En ligne:${NC} ${GRN}%s${NC}   ${GRY}📦 Total:${NC} ${WHT}%s${NC}   ${GRY}⛔ Bloqué:${NC} ${RED}%s${NC}" "$online" "$total" "$blocked"; printf "\033[%dG${CYN}┃${NC}\n" "$((W + 2))"
  printf "${CYN}┃${NC} ${GRY}📊 Conso — hier:${NC} %s ${GRY}· auj.:${NC} %s ${GRY}· mois:${NC} %s" "$(_hr "$hier")" "$(_hr "$auj")" "$(_hr "$mois")"; printf "\033[%dG${CYN}┃${NC}\n" "$((W + 2))"
}

# Tableau de bord d'un protocole précis (affiché en en-tête de son menu)
#   $1 = fichier DB sous /etc/nvpanel/db/   ·   $2 = mode online : ssh | port:PORT | wg
proto_dash() {
  local dbf="$1" mode="$2" tag="$3" total online blocked hier auj mois
  total=$(grep -c '^### ' "/etc/nvpanel/db/$dbf" 2>/dev/null); total=${total:-0}
  online=0; blocked=0
  case "$mode" in
    ssh)
      online=$(_ssh_online)
      if [ -f "/etc/nvpanel/db/$dbf" ]; then
        while read -r _ u _; do
          [ -z "$u" ] && continue
          local st; st=$(passwd -S "$u" 2>/dev/null | awk '{print $2}')
          [ "$st" = "L" ] && blocked=$((blocked+1))
        done < "/etc/nvpanel/db/$dbf"
      fi ;;
    port:*)
      local p="${mode#port:}"
      online=0
      [ "$total" -gt 0 ] && online=$(_online_uniq_port "$p")
      blocked=$(awk '/^### /{if($5=="L")c++} END{print c+0}' "/etc/nvpanel/db/$dbf" 2>/dev/null); blocked=${blocked:-0} ;;
    xray)
      # Auparavant : un seul total de sockets partagé sur le port public
      # nginx (_xray_online), affiché IDENTIQUE dans les menus Vmess, Vless
      # et Trojan — Xray ne voit que 127.0.0.1 en interne, impossible de
      # les distinguer par ce biais. Désormais : nvpanel-cli xonline compte
      # les comptes de CE protocole précis dont l'activité est en cours
      # (même échantillonnage que « connecté depuis »), donc chaque menu
      # affiche enfin son propre chiffre.
      online=0
      [ "$total" -gt 0 ] && online=$(nvpanel-cli xonline "$dbf" 2>/dev/null); online=${online:-0}
      blocked=$(awk '/^### /{if($5=="L")c++} END{print c+0}' "/etc/nvpanel/db/$dbf" 2>/dev/null); blocked=${blocked:-0} ;;
    wg)
      online=$(wg show wg0 latest-handshakes 2>/dev/null | awk -v n="$(date +%s)" '$2>0 && (n-$2)<180{c++} END{print c+0}') ;;
    ppp:*)
      local pp="${mode#ppp:}"
      online=0
      # Sans ce garde-fou, un pppd résiduel ou un scan quelconque pouvait
      # apparaître comme un client en ligne même sans aucun compte créé
      # pour ce protocole précis (même bug déjà corrigé pour Xray/SS ci-dessus).
      [ "$total" -gt 0 ] && { online=$(nvpanel-ppp online "$pp" 2>/dev/null); online=${online:-0}; }
      blocked=$(awk '/^### /{if($5=="L")c++} END{print c+0}' "/etc/nvpanel/db/$dbf" 2>/dev/null); blocked=${blocked:-0} ;;
  esac
  IFS='|' read -r hier auj mois <<< "$(_conso_raw "$tag")"
  printf " ${GRY}📦 Comptes:${NC} ${WHT}%s${NC}   ${GRY}👥 En ligne:${NC} ${GRN}%s${NC}   ${GRY}⛔ Bloqué:${NC} ${RED}%s${NC}\n" "$total" "$online" "$blocked"
  if [ "$tag" = "ppp" ]; then
    # L2TP, PPTP et SSTP partagent tous l'interface ppp+ : impossible de
    # distinguer leur trafic au niveau noyau (limite technique, pas un bug).
    printf " ${GRY}📊 Trafic PPP (L2TP+PPTP+SSTP) — auj.:${NC} %s ${GRY}· mois:${NC} %s\n" "$(_hr "$auj")" "$(_hr "$mois")"
  else
    printf " ${GRY}📊 Trafic — auj.:${NC} %s ${GRY}· mois:${NC} %s\n" "$(_hr "$auj")" "$(_hr "$mois")"
  fi
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
  local __v="$2" buf="" ch e _tty
  [ -n "$1" ] && printf '%b' "$1"
  # Entrée non interactive : on propage la fin de fichier, sinon une boucle
  # de menu tournerait indéfiniment dans le vide.
  if [ ! -t 0 ]; then
    if IFS= read -r buf; then printf -v "$__v" '%s' "$buf"; return 0; fi
    printf -v "$__v" '%s' "$buf"; return 1
  fi

  # L'écho du terminal est coupé pendant TOUTE la saisie.
  # « read -rsn1 » ne le coupe que le temps d'un caractère : entre deux tours
  # de boucle il redevient actif, et une rafale de séquences (le défilement
  # de l'écran en envoie beaucoup) s'affiche alors toute seule sous forme
  # de ^[[A / ^[[B avant même que bash ne la lise.
  # Si le panel n'a pas déjà coupé l'écho (script lancé seul), on le fait ici.
  if [ -z "${NVPANEL_TTY:-}" ]; then
    _tty=$(stty -g 2>/dev/null)
    [ -n "$_tty" ] && stty -echo 2>/dev/null
  fi

  local _eof=1
  while IFS= read -rsn1 ch 2>/dev/null; do
    _eof=0
    case "$ch" in
      '')       break ;;                                  # Entrée
      $'\e')    # séquence d'échappement : avalée jusqu'à son caractère final
                e=''
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

  [ -n "$_tty" ] && stty "$_tty" 2>/dev/null
  printf '\n'
  printf -v "$__v" '%s' "$buf"
  # Entrée fermée (plus de terminal) : on le signale pour éviter
  # qu'une boucle de menu tourne indéfiniment dans le vide.
  [ "$_eof" = 1 ] && [ -z "$buf" ] && return 1
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
# Lecture avec écho garanti (utilisée par les écrans qui ne passent pas par ask).
ask_echo(){ ask "$1" "$2"; }

ui_enter(){
  if [ -z "${NVPANEL_UI:-}" ]; then
    export NVPANEL_UI=$$
    # PAS d'écran séparé : il interdisait tout défilement.
    # Les doublons ne venaient pas de l'effacement mais du DÉBORDEMENT :
    # un affichage plus haut que l'écran pousse ses premières lignes dans
    # l'historique. Le menu tenant désormais à l'écran, rien ne déborde,
    # donc rien ne s'empile — et on peut défiler librement.
    export NVPANEL_TTY="$(stty -g 2>/dev/null)"
    stty -echo 2>/dev/null
  fi
}





# Quitte l'écran séparé sans condition : à utiliser avant un message qui doit
# rester lisible après la fermeture du panel (désinstallation par exemple).
ui_screen_off(){ stty echo icanon 2>/dev/null; }

ui_leave(){
  [ "${NVPANEL_UI:-}" = "$$" ] || return 0
  # Sans écran séparé, rien n'est effacé en sortant : les messages d'erreur
  # restent naturellement visibles, plus besoin de les capturer.
  if [ -n "${NVPANEL_TTY:-}" ]; then stty "$NVPANEL_TTY" 2>/dev/null
  else stty echo icanon 2>/dev/null; fi
}






# animation de chargement stylée avec pourcentage (comme l'installation)
loading(){
  local msg="${1:-Chargement}" w=28 i p
  printf '\033[H\033[2J\033[3J'; echo; echo
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
