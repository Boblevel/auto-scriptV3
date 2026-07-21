#!/bin/bash
# ============================================================
#  RHAFF SERVICE · mise à jour
#  Re-télécharge la dernière version des scripts depuis GitHub,
#  SANS toucher aux comptes, à la config, au bot ni à Xray,
#  puis relance le menu.
#  Usage :
#    bash <(curl -sL https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main/update.sh)
#  ou, une fois installé, simplement :  update
# ============================================================
REPO_RAW="https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main"

RED='\033[0;31m'; GRN='\033[0;32m'; CYN='\033[0;36m'; YLW='\033[0;33m'; NC='\033[0m'
[ "$EUID" -ne 0 ] && { printf "${RED}✘ Lance en root (sudo su -).${NC}\n"; exit 1; }
[ -d /etc/nvpanel ] || { printf "${RED}✘ nvpanel n'est pas installé. Lance d'abord setup.sh.${NC}\n"; exit 1; }

clear
printf "${CYN}"
cat <<'ART'
   ┌───────────────────────────────────────────────────┐
   │     Mise a jour de  R H A F F   S E R V I C E     │
   └───────────────────────────────────────────────────┘
ART
printf "${NC}\n"

fetch(){
  local name dest="$2"
  for name in "$1" "$1.txt"; do
    curl -fsSL "$REPO_RAW/$name" -o "$dest" 2>/dev/null
    if [ -s "$dest" ] && ! head -c 200 "$dest" | grep -q '404: Not Found'; then
      chmod +x "$dest"; printf "  ${GRN}✔${NC} %s\n" "$1"; return 0
    fi
  done
  printf "  ${RED}✘ %s introuvable sur GitHub (racine du dépôt ?)${NC}\n" "$1"; return 1
}

printf "${CYN}➜${NC} Téléchargement de la dernière version…\n"
fetch ui.sh            /etc/nvpanel/lib/ui.sh
fetch menu             /usr/local/bin/menu
fetch menu-ssh         /usr/local/bin/menu-ssh
fetch menu-bot         /usr/local/bin/menu-bot
fetch menu-xray        /usr/local/bin/menu-xray
fetch menu-ss          /usr/local/bin/menu-ss
fetch menu-settings    /usr/local/bin/menu-settings
fetch menu-uninstall   /usr/local/bin/menu-uninstall
fetch menu-wg          /usr/local/bin/menu-wg
fetch nvpanel-cli      /usr/local/bin/nvpanel-cli
fetch nvpanel-bot      /usr/local/bin/nvpanel-bot
fetch nvpanel-limit    /usr/local/bin/nvpanel-limit
fetch nvpanel-quota    /usr/local/bin/nvpanel-quota
fetch nvpanel-clean    /usr/local/bin/nvpanel-clean
fetch install-slowdns  /usr/local/bin/install-slowdns
fetch install-udp      /usr/local/bin/install-udp
fetch install-xray     /usr/local/bin/install-xray
fetch install-tls      /usr/local/bin/install-tls
fetch update.sh        /usr/local/bin/update

# raccourcis (au cas où)
ln -sf /usr/local/bin/menu /usr/local/bin/acc
ln -sf /usr/local/bin/menu /usr/local/bin/dgh
ln -sf /usr/local/bin/menu-uninstall /usr/local/bin/uninstall

# recharge les services dont le code a pu changer
systemctl daemon-reload >/dev/null 2>&1
systemctl is-active --quiet nvpanel-bot   && systemctl restart nvpanel-bot   >/dev/null 2>&1
systemctl is-active --quiet nvpanel-limit && systemctl restart nvpanel-limit >/dev/null 2>&1

printf "\n${GRN}✔ Mise à jour terminée.${NC} Ouverture du menu…\n"
sleep 1
exec menu
