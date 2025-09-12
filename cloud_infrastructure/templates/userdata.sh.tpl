#!/bin/bash

# Mise à jour du système
apt-get update -y
apt-get upgrade -y

# Installation des dépendances
apt-get install -y python3 python3-pip python3-venv docker.io docker-compose

# Démarrage de Docker
systemctl start docker
systemctl enable docker

# Création du répertoire de l'application
mkdir -p ${app_directory}
cd ${app_directory}

# Clone votre application (à adapter selon votre dépôt)
git clone https://github.com/votre-repo/user_management_app.git .

# Installation et démarrage avec Docker Compose
cd ${app_directory}
docker-compose up -d

# Vérification du déploiement
echo "Application déployée sur http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000"