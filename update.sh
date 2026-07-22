#!/bin/bash
# ============================================================
#  RHAFF SERVICE · mise à jour  (commande : update)
#  Re-télécharge la dernière version depuis GitHub sans toucher
#  aux comptes/config, régénère la façade nginx, relance le menu.
# ============================================================
REPO_RAW="https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main"
RED='\033[0;31m'; GRN='\033[0;32m'; CYN='\033[0;36m'; YLW='\033[0;33m'; WHT='\033[1;37m'; GRY='\033[0;90m'; MAG='\033[0;35m'; NC='\033[0m'
[ "$EUID" -ne 0 ] && { printf "${RED}✘ Lance en root (sudo su -).${NC}\n"; exit 1; }
[ -d /etc/nvpanel ] || { printf "${RED}✘ RHAFF SERVICE n'est pas installé.${NC}\n"; exit 1; }

clear
printf "${CYN}"
cat <<'ART'
   ┌────────────────────────────────────────────────────┐
   │        R H A F F   S E R V I C E                     │
   │        Mise à jour                                   │
   └────────────────────────────────────────────────────┘
ART
printf "${NC}\n"

# ---- Barre de progression animée ---------------------------
BARW=34; CUR=0
draw(){ local p=$1 lbl=$2 f=$(( p*BARW/100 )) e i; e=$(( BARW - f ))
  printf "\r   ${CYN}["
  for ((i=0;i<f;i++)); do printf "${GRN}▰${NC}"; done
  for ((i=0;i<e;i++)); do printf "${GRY}▱${NC}"; done
  printf "${CYN}]${NC} ${WHT}%3d%%${NC}  ${MAG}%-30s${NC}" "$p" "$lbl"; }
fill(){ while [ "$CUR" -lt "$1" ]; do CUR=$((CUR+2)); draw "$CUR" "$2"; sleep 0.015; done; draw "$CUR" "$2"; }

# ---- Téléchargement silencieux -----------------------------
FAILED=""
fetch(){
  local name dest="$2" ok=0
  for name in "$1" "$1.txt"; do
    if curl -fsSL "$REPO_RAW/$name" -o "$dest" 2>/dev/null && [ -s "$dest" ] && ! head -c 200 "$dest" | grep -q '404: Not Found'; then
      chmod +x "$dest"; ok=1; break
    fi
  done
  [ "$ok" = 1 ] || FAILED="$FAILED $1"
}

fill 15 "Téléchargement des composants…"
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
  CUR=$(( CUR<70 ? CUR+3 : CUR )); draw "$CUR" "Téléchargement des composants…"
done

fill 78 "Mise en place…"
ln -sf /usr/local/bin/menu /usr/local/bin/acc 2>/dev/null
ln -sf /usr/local/bin/menu /usr/local/bin/dgh 2>/dev/null
ln -sf /usr/local/bin/menu-uninstall /usr/local/bin/uninstall 2>/dev/null

fill 88 "Redémarrage des services…"
systemctl daemon-reload >/dev/null 2>&1
systemctl is-active --quiet nvpanel-bot   && systemctl restart nvpanel-bot   >/dev/null 2>&1
systemctl is-active --quiet nvpanel-limit && systemctl restart nvpanel-limit >/dev/null 2>&1

fill 96 "Application de la configuration…"
if command -v xray >/dev/null 2>&1 && [ -x /usr/local/bin/install-xray ]; then
  /usr/local/bin/install-xray auto >/dev/null 2>&1
fi
fill 100 "Terminé"
sleep 0.3

clear
printf "${GRN}"
cat <<'DONE'
   ┌──────────────────────────────────────────────────┐
   │        ✔   Mise à jour terminée                    │
   └──────────────────────────────────────────────────┘
DONE
printf "${NC}\n"
if [ -n "$FAILED" ]; then
  printf "   ${RED}⚠ Fichiers manquants sur GitHub :${NC}${YLW}%s${NC}\n" "$FAILED"
  printf "   ${GRY}Uploade-les à la racine du dépôt, puis relance : update${NC}\n\n"
fi
printf "   ${GRY}Ouverture du menu…${NC}\n"
sleep 1
exec menu
