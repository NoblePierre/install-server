#!/bin/bash

set -e

# === CONFIGURATION ===
TS_DIR="$(dirname "$0")"
COMPOSE_FILE="$TS_DIR/docker-compose.yml"

# === INSTALL DOCKER & COMPOSE ===
echo "📦 Installation de Docker..."
apt update && apt install -y docker.io docker-compose
systemctl enable --now docker

# === CRÉATION DU DOSSIER DATA ===
echo "📁 Préparation du volume de données..."
mkdir -p "$TS_DIR/data"

# === LANCEMENT DU CONTAINER ===
echo "🚀 Démarrage de TeamSpeak avec Docker Compose..."
cd "$TS_DIR"
docker-compose up -d

# === FIREWALL ===
echo "🛡️ Ouverture des ports nécessaires via UFW..."
ufw allow 9987/udp
ufw allow 10011/tcp
ufw allow 30033/tcp

# === TOKEN DE CRÉATION ADMIN ===
echo "📋 Token de création d'identité admin (si dispo) :"
sleep 5
docker logs teamspeak 2>&1 | grep -i "token=" || echo "❗ Token pas encore dispo, relance : docker logs teamspeak"

echo -e "\n✅ TeamSpeak installé et lancé via Docker."
