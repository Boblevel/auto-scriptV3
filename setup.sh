#!/bin/bash
# ============================================================
#  RHAFF SERVICE · installateur
# ============================================================
REPO_RAW="https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main"
BRAND="RHAFF SERVICE"
CONTACT="t.me/bigrhaff226"
umask 077

RED='\033[0;31m'; GRN='\033[0;32m'; CYN='\033[0;36m'; YLW='\033[0;33m'; WHT='\033[1;37m'; GRY='\033[0;90m'; MAG='\033[0;35m'; NC='\033[0m'
die(){ printf "${RED}✘ %s${NC}\n" "$1"; exit 1; }

# --- Vérifications ------------------------------------------
[ "$EUID" -ne 0 ] && die "Ce script doit être lancé en root (sudo su -)."
# Le nom de l'hyperviseur ne détermine pas ses permissions effectives.
# Contrôles des capacités et de systemd ci-dessous (KVM/LXC/OpenVZ).
. /etc/os-release 2>/dev/null || die "Distribution inconnue."
echo "$ID $ID_LIKE" | grep -qiE 'ubuntu|debian' || die "Ubuntu ou Debian requis (détecté : $PRETTY_NAME)."
[ -d /run/systemd/system ] || die "systemd (PID 1) requis : image VPS incompatible avec ce panel."
RAM_TOT=$(free -m 2>/dev/null | awk '/Mem:/{print $2}')
case "$(uname -m)" in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) die "Architecture non supportée : $(uname -m) (x86_64 ou arm64 requis)." ;;
esac

valid_domain(){
  local d="$1" label
  [ "${#d}" -le 253 ] && [[ "$d" == *.* ]] && [[ "$d" != *..* ]] || return 1
  IFS='.' read -r -a _labels <<< "$d"
  for label in "${_labels[@]}"; do
    [ "${#label}" -ge 1 ] && [ "${#label}" -le 63 ] || return 1
    [[ "$label" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || return 1
  done
}
valid_ipv4(){
  local ip="$1" octet
  IFS='.' read -r -a _octets <<< "$ip"
  [ "${#_octets[@]}" -eq 4 ] || return 1
  for octet in "${_octets[@]}"; do
    [[ "$octet" =~ ^[0-9]{1,3}$ ]] && [ "$((10#$octet))" -le 255 ] || return 1
  done
}

clear
printf "${CYN}"
cat <<'ART'
   ┌────────────────────────────────────────────────────┐
   │        R H A F F   S E R V I C E                   │
   │        Installation                                │
   └────────────────────────────────────────────────────┘
ART
printf "${NC}\n"
[ -n "$RAM_TOT" ] && [ "$RAM_TOT" -lt 900 ] && printf "${YLW}! RAM %s Mo — 1 Go minimum recommandé.${NC}\n\n" "$RAM_TOT"

# --- Saisies -------------------------------------------------
read -rp "   🌐 Nom de domaine (laisser vide si aucun) : " NVDOMAIN
NVDOMAIN=${NVDOMAIN,,}
[ -z "$NVDOMAIN" ] || valid_domain "$NVDOMAIN" || die "Nom de domaine invalide (FQDN attendu, ex. vpn.example.com)."
read -rp "   🔌 Port (Entrée = 443 par défaut) : " NVPORT
NVPORT=${NVPORT:-443}
[[ "$NVPORT" =~ ^[0-9]{1,5}$ ]] || die "Port invalide (1 à 65535, sauf 80)."
NVPORT=$((10#$NVPORT))
[ "$NVPORT" -ge 1 ] && [ "$NVPORT" -le 65535 ] && [ "$NVPORT" -ne 80 ] \
  || die "Port invalide (1 à 65535, sauf 80 réservé à la façade HTTP)."
case "$NVPORT" in
  22|143|1723|4443|7100|7200|7300|8080|8081|8082|8388|10085)
    die "Le port $NVPORT est réservé à un autre composant du panel." ;;
esac
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
export DEBIAN_FRONTEND=noninteractive
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections 2>/dev/null
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections 2>/dev/null
fill 20 "Installation des dépendances…"
INSTALL_LOG=/var/log/rhaff-install.log
apt-get -o Acquire::Retries=3 -o DPkg::Lock::Timeout=120 update -y >"$INSTALL_LOG" 2>&1 || die "Mise à jour APT échouée. Détails : $INSTALL_LOG"
apt-get -o Acquire::Retries=3 -o DPkg::Lock::Timeout=120 install -y curl wget jq unzip cron screen socat python3 openssl \
    ca-certificates iproute2 procps util-linux net-tools dropbear stunnel4 \
    fail2ban vnstat iptables iptables-persistent nginx certbot qrencode >>"$INSTALL_LOG" 2>&1 \
    || die "Installation des dépendances échouée. Détails : $INSTALL_LOG"

# --- Contrôle des outils indispensables -------------------------------------
# L'installation groupée ci-dessus est silencieuse : si un dépôt est
# momentanément injoignable, elle échoue sans rien dire et le panel se déclare
# prêt. C'est ce qui s'est produit avec jq — absent, toute création de compte
# Xray renvoyait « ERR conf » sans que la cause soit visible nulle part.
# On vérifie donc chaque outil vital et on réessaie individuellement.
_MISSING=""
for _tool_pkg in curl:curl jq:jq openssl:openssl python3:python3 ip:iproute2 ss:iproute2 flock:util-linux nginx:nginx systemctl:systemd crontab:cron iptables:iptables; do
  _t=${_tool_pkg%%:*}; _pkg=${_tool_pkg##*:}
  command -v "$_t" >/dev/null 2>&1 || {
    apt-get -o Acquire::Retries=3 -o DPkg::Lock::Timeout=120 install -y "$_pkg" >>"$INSTALL_LOG" 2>&1
    command -v "$_t" >/dev/null 2>&1 || _MISSING="$_MISSING $_t"
  }
done
if [ -n "$_MISSING" ]; then
  echo
  printf "  Outils indispensables introuvables :%s\n" "$_MISSING"
  printf "  Le serveur n'a pas pu les télécharger. Vérifie sa connexion,\n"
  printf "  puis relance l'installation.\n\n"
  exit 1
fi

# Contrôler le port TCP de la façade nginx avant de toucher au panel.
# Une réinstallation du même panel peut conserver son propre nginx.
if ss -H -ltn 2>/dev/null | awk -v port=":$NVPORT" '$4 ~ (port "$"){found=1} END{exit !found}'; then
  _existing_xport=$(cat /etc/nvpanel/xport 2>/dev/null)
  if [ "$_existing_xport" != "$NVPORT" ] \
     || [ ! -f /etc/nginx/conf.d/rhaff.conf ] \
     || ! ss -H -ltnp 2>/dev/null | awk -v port=":$NVPORT" '$4 ~ (port "$") && /"nginx"/{found=1} END{exit !found}'; then
    die "Le port TCP $NVPORT est déjà occupé. Choisis un port libre sans toucher au service existant."
  fi
fi

# Les protocoles utilisent iptables/NAT : sans NET_ADMIN (certains LXC/OpenVZ),
# impossible de garantir leur fonctionnement. Détecter avant de modifier le panel.
if ! iptables -t filter -S INPUT >>"$INSTALL_LOG" 2>&1 \
   || ! iptables -t nat -S PREROUTING >>"$INSTALL_LOG" 2>&1; then
  die "Pare-feu/NAT non administrable (droits NET_ADMIN du VPS). Demande ces permissions à l'hébergeur. Journal : $INSTALL_LOG"
fi

# ARM64 : le module SlowDNS est lié à un exécutable spécifique à l'architecture.
# Ne pas commencer le déploiement si le domaine implique un binaire absent.
if [ "$ARCH" = arm64 ] && [ -n "$NVDOMAIN" ]; then
  curl -fsSIL --connect-timeout 10 --max-time 20 "$REPO_RAW/dns-server-arm64" >>"$INSTALL_LOG" 2>&1 \
    || die "SlowDNS ARM64 requis mais dns-server-arm64 indisponible dans le dépôt ; aucun déploiement commencé."
fi

# --- Dropbear : démarrage sûr ; conserver OpenSSH et les ports personnalisés ---
_db_listening(){
  ss -H -ltn 2>/dev/null | awk -v p=":$1" '$4 ~ (p "$" ){f=1} END{exit f?0:1}'
}
_db_owned(){
  ss -H -ltnp 2>/dev/null | awk -v p=":$1" '$4 ~ (p "$" ) && /"dropbear"/{f=1} END{exit f?0:1}'
}
_db_port_free(){
  [ "$1" != 22 ] && [ "$1" != "$NVPORT" ] || return 1
  ! _db_listening "$1" || _db_owned "$1"
}
command -v dropbear >/dev/null 2>&1 || die "Dropbear absent après installation APT. Journal : $INSTALL_LOG"
[ -f /etc/default/dropbear ] || touch /etc/default/dropbear || die "Configuration Dropbear inaccessible."
_db_backup=$(mktemp /tmp/rhaff-dropbear.XXXXXX) || die "Sauvegarde Dropbear impossible."
cp -a /etc/default/dropbear "$_db_backup" && chmod 600 "$_db_backup" || die "Sauvegarde Dropbear impossible."
_db_old_port=$(awk -F= '/^DROPBEAR_PORT=/{gsub(/["[:space:]]/,"",$2); p=$2} END{print p}' /etc/default/dropbear)
_db_old_ok=0
if [[ "$_db_old_port" =~ ^[0-9]+$ ]] && [ "$_db_old_port" -ne 22 ] \
   && systemctl is-active --quiet dropbear && _db_owned "$_db_old_port"; then
  _db_old_ok=1
fi
# Un port réellement personnalisé est conservé. Les ports automatiques ont
# des solutions de repli, sans jamais prendre le port 22 d'OpenSSH.
if [[ "$_db_old_port" =~ ^[0-9]+$ ]] \
   && [ "$_db_old_port" -ge 1 ] && [ "$_db_old_port" -le 65535 ] \
   && [ "$_db_old_port" -ne 22 ] && [ "$_db_old_port" -ne 143 ]; then
  _db_candidates=("$_db_old_port")
else
  _db_candidates=(143 1443 2222 22222)
fi
# socket activation ancienne : incompatible avec un service à port configurable.
if systemctl list-unit-files --no-legend dropbear.socket 2>/dev/null | grep -q '^dropbear.socket'; then
  systemctl disable --now dropbear.socket >>"$INSTALL_LOG" 2>&1 || die "Désactivation du socket Dropbear impossible."
fi
systemctl unmask dropbear >>"$INSTALL_LOG" 2>&1 || die "Service Dropbear masqué et non modifiable."
_db_ok=0
for _db_port in "${_db_candidates[@]}"; do
  _db_port_free "$_db_port" || continue
  if [ "$_db_old_ok" = 1 ] && [ "$_db_port" = "$_db_old_port" ]; then
    DROPBEAR_PORT="$_db_port"; _db_ok=1; break
  fi
  # Retirer toutes les valeurs précédentes, y compris une ligne dupliquée.
  sed -i '/^[[:space:]]*NO_START=/d; /^[[:space:]]*DROPBEAR_PORT=/d' /etc/default/dropbear \
    || break
  printf 'NO_START=0\nDROPBEAR_PORT=%s\n' "$_db_port" >> /etc/default/dropbear
  grep -q '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear \
    || printf 'DROPBEAR_EXTRA_ARGS=""\n' >> /etc/default/dropbear
  systemctl reset-failed dropbear >>"$INSTALL_LOG" 2>&1 || true
  if systemctl enable dropbear >>"$INSTALL_LOG" 2>&1 \
     && systemctl restart dropbear >>"$INSTALL_LOG" 2>&1 \
     && systemctl is-active --quiet dropbear \
     && _db_owned "$_db_port"; then
    DROPBEAR_PORT="$_db_port"
    _db_ok=1
    break
  fi
  printf 'Échec Dropbear sur %s/tcp :\n' "$_db_port" >>"$INSTALL_LOG"
  journalctl -u dropbear -n 12 --no-pager >>"$INSTALL_LOG" 2>&1 || true
  # Si la cause est un port non disponible, essayer le suivant.
  systemctl stop dropbear >>"$INSTALL_LOG" 2>&1 || true
done
if [ "$_db_ok" -ne 1 ]; then
  if [ "$_db_old_ok" = 1 ]; then
    # Restaurer uniquement un service auparavant réellement fonctionnel.
    cp -a "$_db_backup" /etc/default/dropbear
    systemctl reset-failed dropbear >>"$INSTALL_LOG" 2>&1 || true
    systemctl restart dropbear >>"$INSTALL_LOG" 2>&1 || true
  else
    # Ne jamais restaurer puis relancer une ancienne configuration sur :22.
    systemctl disable --now dropbear >>"$INSTALL_LOG" 2>&1 || true
  fi
  rm -f "$_db_backup"
  printf '\n  Derniers événements Dropbear :\n' >&2
  journalctl -u dropbear -n 15 --no-pager 2>/dev/null >&2 || true
  die "Dropbear n'a pas pu écouter sur un port disponible. Journal : $INSTALL_LOG (OpenSSH préservé)."
fi
rm -f "$_db_backup"
[ "$DROPBEAR_PORT" = 143 ] || printf '\n  ${YLW}! Port Dropbear : %s/tcp (port 143 indisponible).${NC}\n' "$DROPBEAR_PORT"

# --- Comptes du panel avec shell /bin/false : Dropbear (et OpenSSH selon
# PAM) rejette l'authentification par mot de passe si le shell du compte
# n'est pas listé dans /etc/shells ("invalid shell, rejected" dans les logs
# même avec le bon mot de passe). Sans cette ligne, AUCUN compte créé par
# le panel ne peut se connecter, quel que soit le port ou le mot de passe.
grep -qxF '/bin/false' /etc/shells 2>/dev/null || echo '/bin/false' >> /etc/shells

fill 40 "Déploiement du panel…"
mkdir -p /etc/nvpanel/lib /etc/nvpanel/db
chmod 700 /etc/nvpanel /etc/nvpanel/lib /etc/nvpanel/db 2>/dev/null
IPADDR=$(curl -4fsS --connect-timeout 8 --max-time 15 https://ipv4.icanhazip.com 2>/dev/null | tr -d '\r\n ')
valid_ipv4 "$IPADDR" \
  || IPADDR=$(curl -4fsS --connect-timeout 8 --max-time 15 https://ifconfig.me/ip 2>/dev/null | tr -d '\r\n ')
valid_ipv4 "$IPADDR" || die "Impossible de détecter l'adresse IPv4 publique du VPS."
printf '%s\n' "$IPADDR" > /etc/nvpanel/ip
[ -n "$NVDOMAIN" ] && echo "$NVDOMAIN" > /etc/nvpanel/domain
echo "$NVPORT" > /etc/nvpanel/xport
chmod 600 /etc/nvpanel/ip /etc/nvpanel/domain /etc/nvpanel/xport 2>/dev/null

# Téléchargement SILENCIEUX (détails masqués) — on note juste les manquants
FAILED=""
fetch(){
  local name dest="$2" done=0 tmp
  tmp=$(mktemp "${dest}.XXXXXX") || { FAILED="$FAILED $1"; return; }
  for name in "$1" "$1.txt"; do
    if curl -fsSL --connect-timeout 15 --max-time 120 "$REPO_RAW/$name" -o "$tmp" 2>/dev/null \
       && [ -s "$tmp" ] && ! head -c 200 "$tmp" | grep -q '404: Not Found'; then
      if chmod 700 "$tmp" && mv "$tmp" "$dest"; then done=1; break; fi
    fi
  done
  if [ "$done" != 1 ]; then rm -f "$tmp"; FAILED="$FAILED $1"; fi
}
for pair in \
  "ui.sh:/etc/nvpanel/lib/ui.sh" "menu:/usr/local/bin/menu" "menu-ssh:/usr/local/bin/menu-ssh" \
  "menu-xray:/usr/local/bin/menu-xray" "menu-ss:/usr/local/bin/menu-ss" "menu-wg:/usr/local/bin/menu-wg" \
  "menu-ssh-tls:/usr/local/bin/menu-ssh-tls" "install-ssh-tls:/usr/local/bin/install-ssh-tls" \
  "menu-bot:/usr/local/bin/menu-bot" "menu-settings:/usr/local/bin/menu-settings" \
  "menu-uninstall:/usr/local/bin/menu-uninstall" "nvpanel-cli:/usr/local/bin/nvpanel-cli" \
  "nvpanel-bot:/usr/local/bin/nvpanel-bot" "nvpanel-limit:/usr/local/bin/nvpanel-limit" \
  "nvpanel-net-tune:/usr/local/bin/nvpanel-net-tune" \
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
done
[ -z "$FAILED" ] || die "Composants indispensables non téléchargés :$FAILED"
ln -sf /usr/local/bin/menu /usr/local/bin/acc 2>/dev/null
ln -sf /usr/local/bin/menu /usr/local/bin/dgh 2>/dev/null
ln -sf /usr/local/bin/menu-uninstall /usr/local/bin/uninstall 2>/dev/null

fill 62 "Configuration des services…"
( crontab -l 2>/dev/null | grep -v nvpanel-clean; echo "*/10 * * * * /usr/local/bin/nvpanel-clean" ) | crontab - 2>/dev/null \
  || die "Installation de la tâche de nettoyage automatique échouée."
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
cat > /etc/systemd/system/nvpanel-xlimit.service <<'EOF'
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
EOF
systemctl daemon-reload 2>/dev/null
systemctl enable --now nvpanel-limit >/dev/null 2>&1 || die "Le service de limite SSH n'a pas pu démarrer."
systemctl enable --now nvpanel-xlimit >/dev/null 2>&1 || die "Le service de limite Xray n'a pas pu démarrer."
sleep 1
systemctl is-active --quiet nvpanel-limit || die "Le service de limite SSH s'est arrêté après son démarrage."
systemctl is-active --quiet nvpanel-xlimit || die "Le service de limite Xray s'est arrêté après son démarrage."
# Réglages réseau validés : appliqués avant le démarrage de SlowDNS afin que
# son socket UDP soit créé directement avec le bon buffer.
if [ -x /usr/local/bin/nvpanel-net-tune ]; then
  /usr/local/bin/nvpanel-net-tune install >>"$INSTALL_LOG" 2>&1 \
    || printf '\n  ${YLW}! Optimisation réseau non disponible sur ce VPS ; installation poursuivie.${NC}\n'
fi
( crontab -l 2>/dev/null | grep -v nvpanel-quota; echo "*/5 * * * * /usr/local/bin/nvpanel-quota check" ) | crontab - 2>/dev/null \
  || die "Installation de la tâche de quota échouée."
# compteur de consommation CLIENTS (n'inclut pas le trafic propre du serveur)
[ -x /usr/local/bin/nvpanel-conso ] && /usr/local/bin/nvpanel-conso setup >/dev/null 2>&1 \
  || die "Initialisation du compteur de consommation échouée."
( crontab -l 2>/dev/null | grep -v nvpanel-conso; echo "*/5 * * * * /usr/local/bin/nvpanel-conso poll" ) | crontab - 2>/dev/null \
  || die "Installation de la tâche de consommation échouée."
# relevé d'activité des comptes Xray : à la minute, pour que la colonne
# « CONNECTÉ DEPUIS » soit précise sans jamais interroger le réseau
( crontab -l 2>/dev/null | grep -v 'nvpanel-cli xsample'; echo "* * * * * /usr/local/bin/nvpanel-cli xsample" ) | crontab - 2>/dev/null \
  || die "Installation du relevé d'activité Xray échouée."

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
  ufw allow "$DROPBEAR_PORT/tcp" >/dev/null 2>&1 || die "Ouverture du port Dropbear dans UFW impossible."
fi
iptables -C INPUT -p tcp --dport "$DROPBEAR_PORT" -j ACCEPT 2>/dev/null \
  || iptables -I INPUT -p tcp --dport "$DROPBEAR_PORT" -j ACCEPT 2>/dev/null \
  || die "Ouverture du port Dropbear dans le pare-feu impossible."
netfilter-persistent save >/dev/null 2>&1 || die "Impossible de rendre le pare-feu persistant."

# --- Message d'accueil du serveur (MOTD) ---------------------------------
# Ubuntu et Debian affichent au login un long texte : bannière de la
# distribution, publicités, message de l'hébergeur (Contabo, OVH…).
# Il s'imprime AVANT le panel et reste visible quand on fait défiler.
# Le fichier .hushlogin le désactive proprement, sans rien supprimer :
# il suffit de l'effacer pour retrouver le message d'origine.
touch /root/.hushlogin 2>/dev/null
[ -n "${SUDO_USER:-}" ] && [ -d "/home/${SUDO_USER}" ] && \
  touch "/home/${SUDO_USER}/.hushlogin" 2>/dev/null


fill 80 "Préparation des protocoles…"
PROTO_FAILED=""
if [ -x /usr/local/bin/install-xray ]; then
  /usr/local/bin/install-xray auto >>"$INSTALL_LOG" 2>&1 || PROTO_FAILED="$PROTO_FAILED Xray"
else
  PROTO_FAILED="$PROTO_FAILED Xray"
fi
# UDP (UDPGW) activé d'office : le paquet badvpn vient des dépôts officiels,
# donc cela fonctionne sur tous les VPS Debian/Ubuntu sans binaire à héberger.
if [ -x /usr/local/bin/install-udp ]; then
  /usr/local/bin/install-udp auto >>"$INSTALL_LOG" 2>&1 || PROTO_FAILED="$PROTO_FAILED UDPGW"
else
  PROTO_FAILED="$PROTO_FAILED UDPGW"
fi

fill 90 "Préparation de SlowDNS…"
if [ -n "$NVDOMAIN" ]; then
  if [ -x /usr/local/bin/install-slowdns ]; then
    /usr/local/bin/install-slowdns auto "ns-$NVDOMAIN" >>"$INSTALL_LOG" 2>&1 || PROTO_FAILED="$PROTO_FAILED SlowDNS"
  else
    PROTO_FAILED="$PROTO_FAILED SlowDNS"
  fi
fi

# SSH SSL/TLS est facultatif sans domaine public valide : ne jamais bloquer
# les autres protocoles à cause de DNS / Let's Encrypt / pare-feu du fournisseur.
SSH_TLS_NOTE=''
if [ -z "$NVDOMAIN" ]; then
  SSH_TLS_NOTE='en attente : domaine requis pour le certificat TLS'
elif [ -s /etc/nvpanel/ssh-tls/port ] && [ -f /etc/systemd/system/nvpanel-ssh-tls.service ]; then
  # Reinstallation sur un VPS déjà configuré : ne pas modifier le port et
  # ne pas réactiver un service que l'administrateur avait arrêté.
  if systemctl is-active --quiet nvpanel-ssh-tls; then
    SSH_TLS_NOTE="actif : port $(cat /etc/nvpanel/ssh-tls/port)/tcp"
  else
    SSH_TLS_NOTE='déjà configuré et arrêté : état conservé'
  fi
elif [ -x /usr/local/bin/install-tls ] && [ -x /usr/local/bin/install-ssh-tls ]; then
  if /usr/local/bin/install-tls auto >>"$INSTALL_LOG" 2>&1 \
     && /usr/local/bin/install-ssh-tls auto >>"$INSTALL_LOG" 2>&1; then
    SSH_TLS_NOTE="activé automatiquement : port $(cat /etc/nvpanel/ssh-tls/port)/tcp"
  else
    SSH_TLS_NOTE="en attente : vérifie le domaine, le port 80 et le journal $INSTALL_LOG"
    printf "\n  ${YLW}! SSH SSL/TLS non activé : %s.${NC}\n" "$SSH_TLS_NOTE"
  fi
else
  SSH_TLS_NOTE='en attente : installateurs TLS absents'
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

[ -z "$PROTO_FAILED" ] || die "Installation incomplète, protocoles en échec :$PROTO_FAILED. Consulte : $INSTALL_LOG"

# --- Écran final --------------------------------------------
IPADDR=$(cat /etc/nvpanel/ip 2>/dev/null)
clear
printf "${GRN}"
cat <<'DONE'
   ┌──────────────────────────────────────────────────┐
   │                                                  │
   │      ✔   R H A F F   S E R V I C E   installé    │
   │                                                  │
   └──────────────────────────────────────────────────┘
DONE
printf "${NC}\n"
printf "   ${CYN}▶ Pour ouvrir le panel, tape l'une de ces commandes :${NC}\n\n"
printf "         ${WHT}menu${NC}      ${GRY}·${NC}      ${WHT}acc${NC}      ${GRY}·${NC}      ${WHT}dgh${NC}\n\n"
printf "   ${GRY}🌐 IP du serveur : %s${NC}\n\n" "$IPADDR"
printf "   ${GRY}🔐 Port HTTPS / Xray : %s/tcp${NC}\n" "$NVPORT"
printf "   ${GRY}🔌 Port Dropbear : %s/tcp${NC}\n" "$DROPBEAR_PORT"
printf "   ${GRY}🔐 SSH SSL/TLS : %s${NC}\n\n" "$SSH_TLS_NOTE"
if [ -n "$FAILED" ]; then
  printf "   ${YLW}⚠ Installation partielle : certains composants n'ont pas pu être${NC}\n"
  printf "   ${YLW}  récupérés.${NC} ${GRY}Vérifie la connexion puis tape : update${NC}\n\n"
fi
