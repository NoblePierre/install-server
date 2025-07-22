#!/bin/bash

set -e

# === CONFIGURATION ===
TS_DIR="$(dirname "$0")"
COMPOSE_FILE="$TS_DIR/docker-compose.yml"

echo "🔄 Mise à jour de TeamSpeak Docker..."

# Aller dans le dossier du projet
cd "$TS_DIR"

# Télécharger la dernière image
echo "📥 Pull de la dernière image teamspeak..."
docker pull teamspeak

# Redémarrage avec la nouvelle image
echo "♻️ Reconstruction du conteneur avec docker-compose..."
docker-compose down
docker-compose up -d

# Vérification du token admin
echo "📋 Recherche de token de création d'identité admin :"
sleep 5
docker logs teamspeak 2>&1 | grep -i "token=" || echo "ℹ️ Aucun nouveau token généré (probablement déjà initialisé)"

echo -e "\n✅ Mise à jour terminée."
