# nvpanel

Panel de gestion de comptes VPN/tunneling pour VPS **Ubuntu / Debian**
(toutes versions : Ubuntu 20.04/22.04/24.04, Debian 11/12…).
Services : SSH, SlowDNS, UDP, et à venir Xray (Vmess/Vless/Trojan), Shadowsocks.

## Installation (une ligne)

```bash
bash <(curl -sL https://raw.githubusercontent.com/Boblevel/auto-scriptV3/main/setup.sh)
```

## Ouvrir le panel

Trois raccourcis identiques :

```bash
menu      # ou
acc       # ou
dgh
```

## Commandes

| Commande | Rôle |
|---|---|
| `menu` / `acc` / `dgh` | ouvrir le panel |
| `menu-ssh` | gérer SSH / SlowDNS / UDP |
| `install-xray` | installer le cœur Xray |
| `menu-xray vmess\|vless\|trojan` | gérer les clients Xray |
| `menu-ss` | gérer Shadowsocks |
| `menu-settings` | définir le domaine + activer le TLS |
| `install-tls` | activer HTTPS (nginx + Let's Encrypt) |
| `menu-bot` | configurer et activer le bot Telegram |
| `install-slowdns` | installer SlowDNS (dnstt) |
| `install-udp` | installer l'UDP (badvpn + udp-custom) |
| `nvpanel-cli create u p j [lim] [Go]` | créer un compte |
| `nvpanel-cli list` | lister les comptes |
| `nvpanel-cli renew u j` | prolonger |
| `nvpanel-cli lock/unlock u` | (dé)verrouiller |
| `nvpanel-cli delete u` | supprimer |
| `nvpanel-cli status` | infos serveur |
| `journalctl -u nvpanel-bot -f` | logs du bot |
| `uninstall` / `menu-uninstall` | désinstaller entièrement nvpanel |

## Bot Telegram

1. Crée un bot via **@BotFather** → récupère le TOKEN.
2. Récupère ton ID via **@userinfobot**.
3. Sur le VPS : `menu-bot` → option 1 → colle le token et l'ID → activation.
4. Sur Telegram : `/start`. Boutons alignés horizontalement (Créer, Liste,
   Verrouiller, Déverrouiller, Prolonger, Supprimer, Serveur).
   Le bot n'obéit qu'à ton ID admin.

## Structure du dépôt

```
setup.sh             installateur (lien one-line)
lib/ui.sh            interface partagée
bin/menu             menu principal
bin/menu-ssh         SSH + SlowDNS + UDP + limite + quota
bin/install-xray     cœur Xray (vmess/vless/trojan/ss)
bin/menu-xray        clients Vmess / Vless / Trojan
bin/menu-ss          clients Shadowsocks
bin/menu-settings    domaine + activation TLS
bin/install-tls      nginx + certificat Let's Encrypt
bin/menu-uninstall   désinstallation complète
bin/nvpanel-clean    purge auto des comptes expirés
bin/menu-bot         configuration du bot
bin/nvpanel-cli      CLI partagée (panel + bot)
bin/nvpanel-bot      bot Telegram (python3, stdlib)
bin/install-slowdns  SlowDNS (dnstt)
bin/install-udp      UDP (badvpn + udp-custom)
bin/nvpanel-limit    démon limite d'appareils
bin/nvpanel-quota    quota de bande passante
bin-blobs/           binaires à héberger (dns-server, badvpn-udpgw, udp-custom)
```

## Activer le HTTPS (TLS)

1. Pointe un domaine (enregistrement A) vers l'IP du VPS.
2. `menu-settings` → option 1 (définir le domaine) → option 2 (activer le TLS).
   nginx obtient un certificat Let's Encrypt et sert Vmess/Vless/Trojan en
   WebSocket sur le port 443. Les liens générés ensuite utilisent TLS.
   Le certificat se renouvelle automatiquement.

## Binaires (`bin-blobs/`)

SlowDNS et UDP ont besoin de binaires compilés. Héberge-les dans ton dépôt,
puis remplace `Boblevel/auto-scriptV3` dans `install-slowdns` / `install-udp`
(variables `SLDNS_BIN_URL`, `BADVPN_URL`, `UDPCUSTOM_URL`).

## Mettre en ligne sur GitHub

```bash
git init
git add .
git commit -m "nvpanel"
git branch -M main
git remote add origin https://github.com/Boblevel/auto-scriptV3.git
git push -u origin main
```
Puis remplace `Boblevel/auto-scriptV3` par `Boblevel/auto-scriptV3` dans `setup.sh`.
