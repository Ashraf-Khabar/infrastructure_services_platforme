#!/bin/bash

# Mise à jour et installation
apt-get update -y
apt-get upgrade -y
apt-get install -y docker.io docker-compose git

# Démarrage de Docker
systemctl start docker
systemctl enable docker

# Création du répertoire de l'application
mkdir -p /home/ubuntu/user_management_app
cd /home/ubuntu/user_management_app

# Cette partie sera copiée par Jenkins via SCP

# Si docker-compose.yml n'existe pas, créez une structure minimale
if [ ! -f "docker-compose.yml" ]; then
    echo "Création d'une structure Docker minimale..."
    
    # docker-compose.yml
    cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  api:
    build: ./api
    ports:
      - "5000:5000"
    environment:
      - FLASK_ENV=production
      - PYTHONPATH=/app
    volumes:
      - ./api:/app

  client:
    build: ./client
    ports:
      - "8083:8083"
    environment:
      - FLASK_ENV=production
    volumes:
      - ./client:/app
    depends_on:
      - api
EOF

    # API Dockerfile
    mkdir -p api
    cat > api/Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
EOF

    # Client Dockerfile
    mkdir -p client
    cat > client/Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
EOF

    # Fichiers minimaux
    cat > api/requirements.txt << 'EOF'
flask==2.3.3
EOF

    cat > api/app.py << 'EOF'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({"message": "User Management API", "status": "ok"})

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "api"})

@app.route('/api/users')
def get_users():
    return jsonify({"users": [], "count": 0, "status": "ok"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

    cat > client/requirements.txt << 'EOF'
flask==2.3.3
EOF

    cat > client/app.py << 'EOF'
from flask import Flask, jsonify, render_template
import requests
app = Flask(__name__)

@app.route('/')
def home():
    try:
        response = requests.get('http://api:5000/api/users', timeout=2)
        users_data = response.json()
    except:
        users_data = {"users": []}
    
    return render_template('index.html', 
                         message="User Management System",
                         users=users_data.get('users', []),
                         api_status="connected" if users_data else "disconnected")

@app.route('/health')
def health():
    try:
        response = requests.get('http://api:5000/health', timeout=2)
        api_status = response.json()
    except:
        api_status = {"status": "unreachable"}
    
    return jsonify({
        "message": "User Management Client", 
        "status": "ok",
        "api_status": api_status
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8083, debug=False)
EOF

    # Template minimal
    mkdir -p client/templates
    cat > client/templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>User Management System</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>User Management System</h1>
        <p>Application en cours de déploiement...</p>
    </div>
</body>
</html>
EOF
fi

# Construction et démarrage avec Docker Compose
echo "Construction des images Docker..."
docker-compose build

echo "Démarrage des services..."
docker-compose up -d

# Attente du démarrage
echo "Attente du démarrage des services..."
sleep 20

# Vérification
echo "=== CONTAINERS ==="
docker ps
echo ""

echo "=== LOGS ==="
docker-compose logs --tail=10
echo ""

echo "=== HEALTH CHECKS ==="
curl -s http://localhost:5000/health || echo "API health check failed"
echo ""
curl -s http://localhost:8083/health || echo "Client health check failed"
echo ""

# Information d'accès
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "=================================================="
echo "Application déployée!"
echo "API: http://$PUBLIC_IP:5000"
echo "Interface: http://$PUBLIC_IP:8083"
echo "=================================================="

# Script de monitoring
cat > /home/ubuntu/monitor_docker.sh << 'EOF'
#!/bin/bash
while true; do
    echo "=== $(date) ==="
    echo "Containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo "=========================="
    sleep 30
done
EOF

chmod +x /home/ubuntu/monitor_docker.sh
nohup /home/ubuntu/monitor_docker.sh > /home/ubuntu/docker_monitor.log 2>&1 &