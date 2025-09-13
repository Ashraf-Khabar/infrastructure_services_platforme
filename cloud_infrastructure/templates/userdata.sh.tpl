#!/bin/bash

# Mise à jour du système
apt-get update -y
apt-get upgrade -y

# Installation des dépendances
apt-get install -y python3 python3-pip python3-venv docker.io docker-compose git

# Démarrage de Docker
systemctl start docker
systemctl enable docker

# Création du répertoire de l'application
mkdir -p /home/ubuntu/user_management_app
cd /home/ubuntu/user_management_app

# Clone votre application (à adapter avec votre dépôt Git)
git clone https://github.com/votre-username/votre-repo.git . || echo "Clone failed, continuing..."

# Si le clone échoue, créez une structure minimale
if [ ! -f docker-compose.yml ]; then
    echo "Création d'une structure minimale..."
    mkdir -p api client
    
    # Fichier docker-compose.yml minimal
    cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  api:
    build: ./api
    ports:
      - "5000:5000"
    environment:
      - FLASK_ENV=production
  client:
    build: ./client  
    ports:
      - "80:80"
    depends_on:
      - api
EOF

    # Fichier Dockerfile minimal pour l'API
    mkdir -p api
    cat > api/Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
EOF

    cat > api/requirements.txt << 'EOF'
flask==2.3.3
requests==2.31.0
EOF

    cat > api/app.py << 'EOF'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({"message": "User Management API"})

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF
fi

# Installation et démarrage avec Docker Compose
cd /home/ubuntu/user_management_app
docker-compose up -d

# Vérification du déploiement
echo "Application déployée sur http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000"
echo "Health check: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000/health"