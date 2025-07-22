#!/bin/bash

set -e

# === CONFIG ===
# Vérification du paramètre du domaine
if [ $# -eq 0 ]; then
    echo "❌ Erreur: Domaine du panel requis"
    echo "Usage: $0 <panel_domain>"
    echo "Exemple: $0 panel.mondomaine.com"
    exit 1
fi

PANEL_DOMAIN="$1"
WINGS_BINARY="/usr/local/bin/wings"
WINGS_CONFIG_DIR="/etc/pterodactyl"

# Chargement des variables d'environnement
if [ -f .env ]; then
    echo "📄 Chargement du fichier .env..."
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "⚠️  Fichier .env non trouvé, création depuis env.example..."
    cp env.example .env
    echo "📝 Édite le fichier .env avec tes configurations, puis relance le script"
    echo "⏸️  Appuie sur une touche pour éditer .env..."
    read
    nano .env
    export $(cat .env | grep -v '^#' | xargs)
fi

# Affichage de la configuration
echo "🔧 Configuration détectée :"
echo "   Panel Domain: $PANEL_DOMAIN"
echo "   Wings Binary: $WINGS_BINARY"
echo "   Wings Config: $WINGS_CONFIG_DIR"
echo ""

echo "📦 Mise à jour système & installation dépendances..."
apt update && apt upgrade -y

# Installation de Docker Engine
apt install -y docker.io

# Installation manuelle de Docker Compose v2
DOCKER_COMPOSE_VERSION="2.24.6"
mkdir -p ~/.docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-linux-x86_64" \
    -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# Vérifie que tout fonctionne
docker compose version

echo "🐳 Démarrage des services Docker..."
systemctl enable --now docker

echo "📁 Création des dossiers nécessaires..."
mkdir -p uploads
mkdir -p $WINGS_CONFIG_DIR

echo "🚀 Démarrage du Panel Pterodactyl (Docker)..."
docker-compose up -d

echo "⏳ Attente du démarrage des services..."
sleep 30

echo "🔧 Configuration initiale du Panel..."
docker-compose exec panel php artisan key:generate --force
docker-compose exec panel php artisan migrate --seed --force

echo "🧑‍💻 Création de l'utilisateur admin..."
echo "➡️  Accède au panel sur http://$PANEL_DOMAIN"
echo "➡️  Crée ton compte admin via l'interface web"
echo "⏸️  Appuie sur une touche quand c'est fait..."
read

echo "🚀 Installation de Wings (installation native)..."
curl -Lo $WINGS_BINARY https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
chmod +x $WINGS_BINARY

echo "🔧 Configuration Wings..."
echo "➡️  Crée une instance node via le Panel"
echo "➡️  Récupère le config.yml et place-le dans $WINGS_CONFIG_DIR/config.yml"
echo "⏸️  Appuie sur une touche quand c'est fait..."
read

if [ ! -f "$WINGS_CONFIG_DIR/config.yml" ]; then
    echo "⚠️  Fichier config.yml non trouvé, création d'un template..."
    cat > $WINGS_CONFIG_DIR/config.yml <<EOF
# Configuration Wings - Remplace par celle générée par le Panel
system:
  data: /var/lib/pterodactyl
  sftp:
    bind_port: 2022
  docker:
    network:
      name: pterodactyl_nw
      driver: bridge
    interface: 172.18.0.1
  allowed_mounts: []
  allowed_startup: []
security:
  ssl:
    enabled: false
    certificate: ""
    key: ""
  csrf:
    trusted_origins: []
  allowed_origins: []
api:
  host: 0.0.0.0
  port: 8080
  ssl:
    enabled: false
    certificate: ""
    key: ""
  upload_limit: 100
  remote: https://$PANEL_DOMAIN
  token: ""
EOF
    echo "📝 Template créé dans $WINGS_CONFIG_DIR/config.yml"
    echo "⚠️  Remplace le token par celui généré par le Panel"
    nano $WINGS_CONFIG_DIR/config.yml
fi

echo "🛠️  Création du service systemd Wings..."
cat > /etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=$WINGS_CONFIG_DIR
ExecStart=$WINGS_BINARY
Restart=always
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now wings

echo "🔐 Configuration du firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 2022/tcp  # SFTP
ufw allow 8080/tcp  # Wings API
ufw --force enable

echo -e "\n✅ Installation hybride terminée !"
echo "📊 Panel (Docker): http://$PANEL_DOMAIN"
echo "🚀 Wings (Native): Service actif sur ce node"
echo ""
echo "📋 Commandes utiles :"
echo "   Panel logs: docker-compose logs -f panel"
echo "   Wings status: systemctl status wings"
echo "   Wings logs: journalctl -u wings -f"
echo "   Redémarrer Panel: docker-compose restart"
echo "   Redémarrer Wings: systemctl restart wings" 