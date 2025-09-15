#!/bin/bash

# Mise à jour du système
apt-get update -y
apt-get upgrade -y

# Installation de Docker
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Installation de Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Ajouter l'utilisateur ubuntu au groupe docker
usermod -aG docker ubuntu

# Création du répertoire de l'application
mkdir -p /home/ubuntu/user_management_app
chown -R ubuntu:ubuntu /home/ubuntu/user_management_app

# Configuration du docker-compose.yml par défaut (sera remplacé par le vrai fichier)
cat > /home/ubuntu/user_management_app/docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Service API
  api:
    build: ./api
    ports:
      - "5000:5000"
    environment:
      - DATABASE_URL=postgresql://user:password@db:5432/user_management
      - PYTHONUNBUFFERED=1
    depends_on:
      - db
    restart: unless-stopped
    networks:
      - app-network

  # Service Client
  client:
    build: ./client
    ports:
      - "8083:8083"
    environment:
      - API_URL=http://api:5000
      - PYTHONUNBUFFERED=1
    depends_on:
      - api
    restart: unless-stopped
    networks:
      - app-network

  # Base de données PostgreSQL
  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=user_management
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped
    networks:
      - app-network

  # Monitoring (optionnel)
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    restart: unless-stopped
    networks:
      - app-network

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped
    networks:
      - app-network

volumes:
  postgres_data:
  grafana_data:

networks:
  app-network:
    driver: bridge
EOF

# Création du fichier init.sql par défaut
cat > /home/ubuntu/user_management_app/init.sql << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertion d'un utilisateur admin par défaut
INSERT INTO users (username, email, password_hash) 
VALUES ('admin', 'admin@example.com', 'hashed_password_here')
ON CONFLICT (username) DO NOTHING;
EOF

# Création du répertoire monitoring
mkdir -p /home/ubuntu/user_management_app/monitoring

# Configuration Prometheus par défaut
cat > /home/ubuntu/user_management_app/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'api'
    static_configs:
      - targets: ['api:5000']
  
  - job_name: 'client'
    static_configs:
      - targets: ['client:8083']
  
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

# Dockerfile API par défaut
mkdir -p /home/ubuntu/user_management_app/api
cat > /home/ubuntu/user_management_app/api/Dockerfile << 'EOF'
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
EOF

# Dockerfile Client par défaut
mkdir -p /home/ubuntu/user_management_app/client
cat > /home/ubuntu/user_management_app/client/Dockerfile << 'EOF'
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8083

CMD ["python", "app.py"]
EOF

# Requirements par défaut
cat > /home/ubuntu/user_management_app/api/requirements.txt << 'EOF'
fastapi==0.104.0
uvicorn[standard]==0.24.0
sqlalchemy==2.0.0
psycopg2-binary==2.9.0
alembic==1.0.0
python-multipart==0.0.0
python-jose==3.0.0
passlib==1.7.0
prometheus-client==0.20.0
EOF

cat > /home/ubuntu/user_management_app/client/requirements.txt << 'EOF'
flask==2.3.3
requests==2.31.0
EOF

# Service systemd pour gérer Docker Compose
cat > /etc/systemd/system/user-management-app.service << 'EOF'
[Unit]
Description=User Management App with Docker Compose
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/user_management_app
ExecStart=/usr/bin/docker-compose up -d --build
ExecStop=/usr/bin/docker-compose down
User=ubuntu
Group=docker
Restart=no

[Install]
WantedBy=multi-user.target
EOF

# Service pour redémarrer automatiquement en cas de crash
cat > /etc/systemd/system/user-management-app-monitor.service << 'EOF'
[Unit]
Description=Monitor and restart User Management App
After=user-management-app.service

[Service]
Type=simple
User=ubuntu
Group=docker
WorkingDirectory=/home/ubuntu/user_management_app
ExecStart=/bin/bash -c 'while true; do if ! docker-compose ps | grep -q "Up"; then docker-compose up -d; fi; sleep 30; done'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Script de santé pour vérifier l'application
cat > /home/ubuntu/health-check.sh << 'EOF'
#!/bin/bash

check_service() {
    local service=$1
    local port=$2
    
    if curl -s -f http://localhost:$port/health > /dev/null; then
        echo "✅ $service is healthy"
        return 0
    else
        echo "❌ $service is not responding"
        return 1
    fi
}

echo "=== Health Check ==="
check_service "API" 5000
check_service "Client" 8083

# Vérifier les conteneurs
echo "=== Docker Containers ==="
docker-compose ps

# Vérifier les logs
echo "=== Recent Logs ==="
docker-compose logs --tail=10
EOF

chmod +x /home/ubuntu/health-check.sh

# Script pour redémarrer l'application
cat > /home/ubuntu/restart-app.sh << 'EOF'
#!/bin/bash
cd /home/ubuntu/user_management_app
docker-compose down
docker-compose up -d --build
echo "Application restarted"
EOF

chmod +x /home/ubuntu/restart-app.sh

# Changement de propriétaire pour tous les fichiers
chown -R ubuntu:ubuntu /home/ubuntu/user_management_app
chown ubuntu:ubuntu /home/ubuntu/health-check.sh
chown ubuntu:ubuntu /home/ubuntu/restart-app.sh

# Activation des services systemd
systemctl daemon-reload
systemctl enable user-management-app.service
systemctl enable user-management-app-monitor.service

# Démarrage de l'application
systemctl start user-management-app.service
systemctl start user-management-app-monitor.service

# Attendre un peu que Docker démarre
sleep 30

# Information d'accès
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || hostname -I | awk '{print $1}')
echo "=================================================="
echo "✅ Environnement Docker préparé avec succès!"
echo "📁 Répertoire: /home/ubuntu/user_management_app"
echo "🐳 Docker et Docker Compose installés"
echo "🔧 Services systemd configurés"
echo "🌐 IP Publique: $PUBLIC_IP"
echo "🚀 Application accessible sur:"
echo "   - API: http://$PUBLIC_IP:5000"
echo "   - Client: http://$PUBLIC_IP:8083"
echo "   - Monitoring: http://$PUBLIC_IP:3000 (admin/admin)"
echo "=================================================="

# Journalisation
echo "Déploiement terminé à $(date)" >> /var/log/user-management-deployment.log