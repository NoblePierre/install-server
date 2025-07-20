#!/bin/bash

set -e

# === VÉRIFICATION DES ARGUMENTS ===
if [ $# -lt 3 ]; then
    echo "Usage: $0 <SSH_PORT> <NEW_USER> <PUBLIC_KEY> [FR_IP_LIST_URL]"
    echo ""
    echo "Arguments:"
    echo "  SSH_PORT        : Port SSH (ex: 2233)"
    echo "  NEW_USER        : Nom de l'utilisateur à créer (ex: admin)"
    echo "  PUBLIC_KEY      : Clé publique SSH complète"
    echo "  FR_IP_LIST_URL  : URL des IP françaises (optionnel, défaut: https://www.ipdeny.com/ipblocks/data/countries/fr.zone)"
    echo ""
    echo "Exemple:"
    echo "  $0 2233 admin 'ssh-ed25519 AAAA...ta_clé_publique... user@machine'"
    exit 1
fi

# === RÉCUPÉRATION DES PARAMÈTRES ===
SSH_PORT="$1"
NEW_USER="$2"
PUB_KEY="$3"
FR_IP_LIST_URL="${4:-https://www.ipdeny.com/ipblocks/data/countries/fr.zone}"

# === VALIDATION DES PARAMÈTRES ===
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    echo "❌ Erreur: Le port SSH doit être un nombre entre 1 et 65535"
    exit 1
fi

if [[ -z "$NEW_USER" ]]; then
    echo "❌ Erreur: Le nom d'utilisateur ne peut pas être vide"
    exit 1
fi

if [[ -z "$PUB_KEY" ]]; then
    echo "❌ Erreur: La clé publique ne peut pas être vide"
    exit 1
fi

# === MISE À JOUR DU SYSTÈME ===
echo "🔄 Mise à jour du système..."
apt update && apt upgrade -y

# === INSTALLATION DES OUTILS ===
echo "🛠️ Installation des paquets nécessaires..."
apt install -y sudo ufw ipset iptables-persistent wget curl

# === CRÉATION UTILISATEUR NON-ROOT ===
echo "👤 Création de l'utilisateur '$NEW_USER'..."
adduser --disabled-password --gecos "" "$NEW_USER"
usermod -aG sudo "$NEW_USER"
mkdir -p /home/$NEW_USER/.ssh
echo "$PUB_KEY" > /home/$NEW_USER/.ssh/authorized_keys
chmod 600 /home/$NEW_USER/.ssh/authorized_keys
chmod 700 /home/$NEW_USER/.ssh
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh

# === CONFIGURATION SSH ===
echo "🔧 Configuration SSH..."
sed -i.bak -E "s/^#?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i -E "s/^#?PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i -E "s/^#?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i -E "s/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/" /etc/ssh/sshd_config

# === CONFIGURATION FIREWALL UFW ===
echo "🛡️ Configuration de UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT"/tcp
ufw enable

# === TÉLÉCHARGEMENT IP FRANCE ===
echo "🌍 Téléchargement des plages IP françaises..."
mkdir -p /etc/ipsets
wget -q -O /etc/ipsets/fr.zone "$FR_IP_LIST_URL"

# === CRÉATION ET PEUPLEMENT DU SET IPSET ===
echo "📦 Création de l'ipset 'france'..."
ipset create france hash:net || true
while read -r ip; do
    ipset add france "$ip" || true
done < /etc/ipsets/fr.zone

# === RÈGLES IPTABLES ===
echo "🚧 Application des règles iptables pour filtrer le SSH..."
iptables -I INPUT -p tcp --dport "$SSH_PORT" -m set --match-set france src -j ACCEPT
iptables -A INPUT -p tcp --dport "$SSH_PORT" -j DROP

# === SAUVEGARDE DES RÈGLES ===
echo "💾 Sauvegarde des règles iptables et ipset..."
ipset save > /etc/ipset.rules
iptables-save > /etc/iptables/rules.v4

# === SCRIPT DE RESTAURATION AU BOOT ===
echo "🔁 Configuration du rechargement au démarrage..."

cat > /etc/network/if-pre-up.d/geoip-ssh-filter <<EOF
#!/bin/bash
ipset create france hash:net 2>/dev/null || true
while read -r ip; do
    ipset add france "\$ip" 2>/dev/null || true
done < /etc/ipsets/fr.zone

iptables -I INPUT -p tcp --dport $SSH_PORT -m set --match-set france src -j ACCEPT
iptables -A INPUT -p tcp --dport $SSH_PORT -j DROP
EOF

chmod +x /etc/network/if-pre-up.d/geoip-ssh-filter

# === REDÉMARRAGE SSH ===
echo "🚀 Redémarrage du service SSH..."
systemctl restart sshd

echo -e "\n✅ Serveur sécurisé !
➡️ Connecte-toi désormais avec :
   ssh -p $SSH_PORT $NEW_USER@IP

🧠 Conseil : garde ta session SSH actuelle ouverte jusqu'à avoir vérifié que la nouvelle fonctionne."
