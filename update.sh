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
rm -f /tmp/nvpanel-relaunch 2>/dev/null

clear
printf "${CYN}"
cat <<'ART'
   ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
   ┃      R H A F F   S E R V I C E           ┃
   ┃         M I S E   À   J O U R             ┃
   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
ART
printf "${NC}\n"

# ---- Progression horizontale dynamique ---------------------
# Une seule ligne est réécrite avec \r : 1 → 100 % sans remplir
# l'historique du terminal ni provoquer les doublons d'affichage.
_PROGRESS=0
# Barre volontairement courte : elle reste sur UNE seule ligne même dans les
# terminaux mobiles étroits. Le retour chariot réécrit cette même ligne.
_BAR_FULL="####################"
_BAR_EMPTY="--------------------"
progress_to(){
  local target="$1" label="$2" i filled empty bar short
  [ "$target" -gt 100 ] && target=100
  case "$label" in
    *Téléchargement*) short="Téléchargement" ;;
    *Mise\ en\ place*) short="Installation" ;;
    *services*) short="Services" ;;
    *configuration*) short="Configuration" ;;
    *terminée*) short="Terminé" ;;
    *) short="$label" ;;
  esac
  for ((i=_PROGRESS+1; i<=target; i++)); do
    filled=$(( i * 20 / 100 )); empty=$((20 - filled))
    bar="${_BAR_FULL:0:filled}${_BAR_EMPTY:0:empty}"
    # Bordure fermée de la barre : [################----] reste complète
    # même pendant la réécriture dynamique sur terminal mobile.
    printf "\r\033[2K ${CYN}[%s]${NC} ${WHT}%3d%%${NC} ${GRY}%-16s${NC}" "$bar" "$i" "$short"
    sleep 0.006
  done
  _PROGRESS=$target
}
progress_to 1 "Préparation"

# ---- Téléchargement silencieux -----------------------------
FAILED=""; CHANGED=0
fetch(){
  local name dest="$2" ok=0 tmp
  tmp=$(mktemp)
  for name in "$1" "$1.txt"; do
    if curl -fsSL "$REPO_RAW/$name" -o "$tmp" 2>/dev/null && [ -s "$tmp" ] && ! head -c 200 "$tmp" | grep -q '404: Not Found'; then
      ok=1; break
    fi
  done
  if [ "$ok" = 1 ]; then
    # Ne compte (et n'écrase) que si le contenu a réellement changé — c'est
    # ce qui permet de distinguer « déjà à jour » d'une vraie mise à jour.
    if [ -f "$dest" ] && cmp -s "$tmp" "$dest" 2>/dev/null; then
      rm -f "$tmp"
    else
      mv "$tmp" "$dest"; chmod +x "$dest"; CHANGED=$((CHANGED+1))
    fi
  else
    rm -f "$tmp"
    FAILED="$FAILED $1"
  fi
}

progress_to 5 "Téléchargement des composants"
_DONE_FILES=0; _TOTAL_FILES=27
for pair in \
  "ui.sh:/etc/nvpanel/lib/ui.sh" "menu:/usr/local/bin/menu" "menu-ssh:/usr/local/bin/menu-ssh" \
  "menu-xray:/usr/local/bin/menu-xray" "menu-ss:/usr/local/bin/menu-ss" "menu-wg:/usr/local/bin/menu-wg" \
  "menu-bot:/usr/local/bin/menu-bot" "menu-settings:/usr/local/bin/menu-settings" \
  "menu-uninstall:/usr/local/bin/menu-uninstall" "nvpanel-cli:/usr/local/bin/nvpanel-cli" \
  "nvpanel-bot:/usr/local/bin/nvpanel-bot" "nvpanel-limit:/usr/local/bin/nvpanel-limit" \
  "nvpanel-quota:/usr/local/bin/nvpanel-quota" "nvpanel-clean:/usr/local/bin/nvpanel-clean" \
  "nvpanel-conso:/usr/local/bin/nvpanel-conso" \
  "menu-ppp:/usr/local/bin/menu-ppp" "nvpanel-ppp:/usr/local/bin/nvpanel-ppp" \
  "install-l2tp:/usr/local/bin/install-l2tp" "install-pptp:/usr/local/bin/install-pptp" \
  "install-sstp:/usr/local/bin/install-sstp" \
  "install-xray:/usr/local/bin/install-xray" "install-tls:/usr/local/bin/install-tls" \
  "install-slowdns:/usr/local/bin/install-slowdns" "install-udp:/usr/local/bin/install-udp" \
  "install-hysteria:/usr/local/bin/install-hysteria" "nvpanel-hysteria:/usr/local/bin/nvpanel-hysteria" \
  "update.sh:/usr/local/bin/update"; do
  fetch "${pair%%:*}" "${pair##*:}"
  _DONE_FILES=$((_DONE_FILES+1))
  progress_to $((5 + _DONE_FILES * 60 / _TOTAL_FILES)) "Téléchargement des composants"
done
progress_to 65 "Téléchargement terminé"

progress_to 72 "Mise en place des composants"
command -v qrencode >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y qrencode >/dev/null 2>&1
ln -sf /usr/local/bin/menu /usr/local/bin/acc 2>/dev/null
ln -sf /usr/local/bin/menu /usr/local/bin/dgh 2>/dev/null
ln -sf /usr/local/bin/menu-uninstall /usr/local/bin/uninstall 2>/dev/null

progress_to 80 "Mise à jour des services"
systemctl daemon-reload >/dev/null 2>&1
# Dropbear : Ubuntu livre NO_START=1, le service ne démarre jamais sans ceci
if dpkg -l 2>/dev/null | grep -q '^ii.*dropbear'; then
  touch /etc/default/dropbear
  # Se déclenche aussi si le port est resté sur 22 (paquet Debian 12 qui le
  # livre déjà décommenté) : avant, on ne réparait que si le service était
  # inactif ou NO_START=1, or Dropbear tournait déjà (sur le mauvais port),
  # donc cette réparation ne s'exécutait jamais sur ces installations.
  if grep -q '^NO_START=1' /etc/default/dropbear \
     || ! systemctl is-active --quiet dropbear 2>/dev/null \
     || grep -q '^DROPBEAR_PORT=22' /etc/default/dropbear; then
    sed -i '/^NO_START=/d' /etc/default/dropbear
    echo 'NO_START=0' >> /etc/default/dropbear
    sed -i '/^DROPBEAR_PORT=/d' /etc/default/dropbear
    echo 'DROPBEAR_PORT=143' >> /etc/default/dropbear
    grep -q '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear || echo 'DROPBEAR_EXTRA_ARGS=""' >> /etc/default/dropbear
    systemctl list-unit-files 2>/dev/null | grep -q '^dropbear.socket' && systemctl disable --now dropbear.socket >/dev/null 2>&1
    systemctl unmask dropbear >/dev/null 2>&1
    systemctl enable dropbear >/dev/null 2>&1
    systemctl restart dropbear >/dev/null 2>&1
  fi
fi
# Comptes du panel avec shell /bin/false : sans /bin/false dans /etc/shells,
# Dropbear rejette l'authentification par mot de passe ("invalid shell,
# rejected") même avec le bon mot de passe. Corrige aussi les installations
# déjà en place.
grep -qxF '/bin/false' /etc/shells 2>/dev/null || echo '/bin/false' >> /etc/shells
# Le bot Telegram n'est PAS redémarré ici : c'est à toi de le faire
# depuis le menu (Bot Telegram → « Redémarrer le bot »).
systemctl is-active --quiet nvpanel-limit && systemctl restart nvpanel-limit >/dev/null 2>&1

progress_to 90 "Application de la configuration"

# --- Message d'accueil du serveur (MOTD) ---------------------------------
# Ubuntu et Debian affichent au login un long texte : bannière de la
# distribution, publicités, message de l'hébergeur (Contabo, OVH…).
# Il s'imprime AVANT le panel et reste visible quand on fait défiler.
# Le fichier .hushlogin le désactive proprement, sans rien supprimer :
# il suffit de l'effacer pour retrouver le message d'origine.
touch /root/.hushlogin 2>/dev/null
[ -n "${SUDO_USER:-}" ] && [ -d "/home/${SUDO_USER}" ] && \
  touch "/home/${SUDO_USER}/.hushlogin" 2>/dev/null

if command -v xray >/dev/null 2>&1 && [ -x /usr/local/bin/install-xray ]; then
  /usr/local/bin/install-xray auto >/dev/null 2>&1
fi
# compteur de consommation CLIENTS (exclut le trafic propre du serveur)
if [ -x /usr/local/bin/nvpanel-conso ]; then
  /usr/local/bin/nvpanel-conso setup >/dev/null 2>&1
  ( crontab -l 2>/dev/null | grep -v nvpanel-conso; echo "*/5 * * * * /usr/local/bin/nvpanel-conso poll" ) | crontab - 2>/dev/null
fi
# statistiques par compte Xray : ajoutées à une configuration existante sans
# jamais toucher aux clients déjà créés, puis relevé d'activité à la minute
if [ -x /usr/local/bin/nvpanel-cli ]; then
  /usr/local/bin/nvpanel-cli xapi >/dev/null 2>&1
  ( crontab -l 2>/dev/null | grep -v 'nvpanel-cli xsample'; echo "* * * * * /usr/local/bin/nvpanel-cli xsample" ) | crontab - 2>/dev/null

  # La limite Xray/Shadowsocks doit réagir en quelques secondes. Ce service
  # n'agit ni sur SSH ni sur SlowDNS.
  cat > /etc/systemd/system/nvpanel-xlimit.service <<'UNIT'
[Unit]
Description=RHAFF SERVICE - limite appareils Xray/SS
After=network-online.target xray.service nginx.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do /usr/local/bin/nvpanel-cli xenforce >/dev/null 2>&1; sleep 5; done'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload >/dev/null 2>&1
  systemctl enable --now nvpanel-xlimit >/dev/null 2>&1
fi
# udp-custom : bascule de l'ancien port 36712 vers l'UDP 22, afin que le client
# saisisse le même port pour SSH, SlowDns et UDP Custom
if [ -f /etc/nvpanel/udp/config.json ] && grep -q '":36712"' /etc/nvpanel/udp/config.json 2>/dev/null; then
  sed -i 's/":36712"/":22"/' /etc/nvpanel/udp/config.json 2>/dev/null
  iptables -D INPUT -p udp --dport 36712 -j ACCEPT 2>/dev/null
  iptables -C INPUT -p udp --dport 22 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p udp --dport 22 -j ACCEPT 2>/dev/null
  systemctl restart nvpanel-udp-custom >/dev/null 2>&1
  [ -x /usr/local/bin/nvpanel-conso ] && /usr/local/bin/nvpanel-conso setup >/dev/null 2>&1
fi
# Réparation des outils indispensables : sur certains serveurs, l'installation
# initiale d'un paquet a pu échouer sans le signaler (jq absent = création de
# compte Xray impossible).
for _t in curl jq openssl python3; do
  command -v "$_t" >/dev/null 2>&1 || apt-get install -y "$_t" >/dev/null 2>&1
done
progress_to 100 "Mise à jour terminée"
printf "\n"

clear
if [ "$CHANGED" -eq 0 ] && [ -z "$FAILED" ]; then
  printf "${GRN}"
  cat <<'UPTODATE'
   ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
   ┃      ✔   Le script est déjà à jour        ┃
   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
UPTODATE
  printf "${NC}\n"
  printf "   ${GRY}Aucun composant n'a changé depuis la dernière mise à jour.${NC}\n\n"
else
  printf "${GRN}"
  cat <<'DONE'
   ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
   ┃       ✔   Mise à jour terminée            ┃
   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
DONE
  printf "${NC}\n"
  [ -z "$FAILED" ] && printf "   ${GRY}Le script est maintenant à jour (%s composant(s) mis à jour).${NC}\n\n" "$CHANGED"
fi
if [ -n "$FAILED" ]; then
  printf "   ${YLW}⚠ Mise à jour partielle : certains composants n'ont pas pu être${NC}\n"
  printf "   ${YLW}  récupérés.${NC} ${GRY}Vérifie la connexion du serveur et relance : update${NC}\n\n"
fi
# Le bot partage les mêmes commandes que le panel. S'il tourne déjà, on le
# redémarre après la mise à jour afin qu'il charge immédiatement les fichiers
# qui viennent d'être remplacés, sans modifier son état activé/désactivé.
if systemctl is-active --quiet nvpanel-bot 2>/dev/null; then
  systemctl restart nvpanel-bot >/dev/null 2>&1 || true
fi
printf "   ${GRY}Ouverture du menu…${NC}\n"
sleep 1
# vide les touches tapées pendant la mise à jour (sinon elles ressortent en ^[[A)
while IFS= read -r -s -t 0.01 -n 512 _ 2>/dev/null; do :; done

# Lancé depuis le panel : signale au menu principal qu'il doit se remplacer
# par la nouvelle version une fois le sous-menu Paramètres refermé. On évite
# ainsi tout empilement de menus tout en rechargeant immédiatement les fichiers.
if [ -n "${NVPANEL_UI:-}" ]; then
  : > /tmp/nvpanel-relaunch
  exit 0
fi
exec menu
