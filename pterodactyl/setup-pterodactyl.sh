#!/bin/bash
# setup-panel.sh - Installe le panel Pterodactyl (sans Docker) sur Debian 12
# ❌ Ne pas lancer en root directement, utiliser sudo ou un user avec droits sudo

set -e

# Gestion des paramètres d'entrée
usage() {
  echo "Usage: $0 [--domain <panel_domain>] [--dbpass <db_password>]"
  echo "  --domain, -d   Domaine du panel (ex: panel.mondomaine.fr)"
  echo "  --dbpass, -p   Mot de passe de la base de données"
  echo "  --help,  -h    Afficher cette aide"
  exit 1
}

# Lecture des arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --domain|-d)
      PANEL_DOMAIN="$2"
      shift 2
      ;;
    --dbpass|-p)
      DB_PASS="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Argument inconnu : $1"
      usage
      ;;
  esac
done

# Vérification des paramètres obligatoires
if [[ -z "$PANEL_DOMAIN" ]]; then
  echo "Erreur : le domaine du panel (--domain) ne peut pas être vide."
  exit 1
fi
if [[ -z "$DB_PASS" ]]; then
  echo "Erreur : le mot de passe de la base de données (--dbpass) ne peut pas être vide."
  exit 1
fi

## Variables
PANEL_DIR="/var/www/pterodactyl"
DB_NAME="pterodactyl"
DB_USER="ptero"
# DB_PASS déjà défini via argument ou valeur par défaut

## Mise à jour & dépendances
sudo apt update && sudo apt install -y \
  nginx mariadb-server php php-cli php-mysql php-mbstring php-xml php-curl php-zip php-bcmath php-gd \
  unzip tar curl git composer nodejs npm redis-server php-redis

## Configuration DB
sudo mysql -e "CREATE DATABASE ${DB_NAME};"
sudo mysql -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';"
sudo mysql -e "FLUSH PRIVILEGES;"

## Téléchargement du panel
sudo mkdir -p $PANEL_DIR
sudo chown -R $USER:$USER $PANEL_DIR
cd $PANEL_DIR
git clone https://github.com/pterodactyl/panel.git .
git checkout `git describe --tags $(git rev-list --tags --max-count=1)`

## Installation backend Laravel
cp .env.example .env
composer install --no-dev --optimize-autoloader
php artisan key:generate --force

## Configuration DB dans .env (non interactif ici)
sed -i \
  -e "s/DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/" \
  -e "s/DB_USERNAME=.*/DB_USERNAME=${DB_USER}/" \
  -e "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/" \
.env

## Migration de la base
php artisan migrate --seed --force

## Stockage, permissions
php artisan p:environment:setup --author="admin@localhost" --url="https://${PANEL_DOMAIN}"
php artisan storage:link
php artisan view:clear
chown -R www-data:www-data $PANEL_DIR

## Configuration Nginx
cat <<EOF | sudo tee /etc/nginx/sites-available/pterodactyl
server {
    listen 80;
    server_name ${PANEL_DOMAIN};
    root ${PANEL_DIR}/public;

    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.(php|php5)$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/pterodactyl
sudo systemctl reload nginx

## Préparation de l'admin
php artisan p:user:make --email=admin@localhost --username=admin --name-first=Admin --name-last=User --password="admin123" --admin

## Installation de Wings (agent Docker)
curl -sSL https://get.docker.com | sh

sudo mkdir -p /etc/pterodactyl
curl -o /etc/pterodactyl/config.yml https://raw.githubusercontent.com/pterodactyl/wings/main/config.example.yml

# Téléchargement de l'exécutable Wings
curl -L https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 -o /usr/local/bin/wings
chmod +x /usr/local/bin/wings

# Créer un service systemd
cat <<EOF | sudo tee /etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
ExecStart=/usr/local/bin/wings
Restart=on-failure
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable --now wings

## Fin
clear
echo -e "\n✅ Panel + Wings installés avec succès."
echo -e "\nAccès panel via : http://${PANEL_DOMAIN}"
echo -e "\nPense à configurer HTTPS et le démon Wings depuis l'interface web."
echo -e "\n⚡ Identifiants admin : admin@localhost / admin123"
