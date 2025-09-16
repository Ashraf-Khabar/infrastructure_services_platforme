#!/bin/bash

apt-get update -y
apt-get upgrade -y
apt-get install -y python3 python3-pip net-tools

mkdir -p /home/ubuntu/user_management_app
cd /home/ubuntu/user_management_app

# Service API
mkdir -p api
cd api

cat > app.py << 'EOF'
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

cat > requirements.txt << 'EOF'
flask==2.3.3
gunicorn==21.2.0
EOF

pip3 install -r requirements.txt

# Service Client
cd ..
mkdir -p client
cd client

cat > app.py << 'EOF'
from flask import Flask, jsonify
import requests
app = Flask(__name__)

@app.route('/')
def home():
    try:
        # Essayer de contacter l'API
        response = requests.get('http://localhost:5000/health', timeout=2)
        api_status = response.json()
    except:
        api_status = {"status": "unreachable"}
    
    return jsonify({
        "message": "User Management Client", 
        "status": "ok",
        "api_status": api_status
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "client"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8083, debug=False)
EOF

cat > requirements.txt << 'EOF'
flask==2.3.3
requests==2.31.0
EOF

pip3 install -r requirements.txt

# Création des services systemd pour API (CORRIGÉ: /etc/systemd/system/)
cat > /etc/systemd/system/user-management-api.service << 'EOF'
[Unit]
Description=User Management API Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/user_management_app/api
ExecStart=/usr/bin/python3 /home/ubuntu/user_management_app/api/app.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

# Création des services systemd pour Client (CORRIGÉ: /etc/systemd/system/)
cat > /etc/systemd/system/user-management-client.service << 'EOF'
[Unit]
Description=User Management Client Service
After=network.target user-management-api.service
Requires=user-management-api.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/user_management_app/client
ExecStart=/usr/bin/python3 /home/ubuntu/user_management_app/client/app.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

# Activation et démarrage des services
systemctl daemon-reload
systemctl enable user-management-api.service
systemctl enable user-management-client.service
systemctl start user-management-api.service
systemctl start user-management-client.service

# Attente du démarrage
echo "Attente du démarrage des services..."
sleep 20

# Vérification
echo "=== STATUS DES SERVICES ==="
systemctl status user-management-api.service --no-pager || echo "Service API non trouvé"
echo ""
systemctl status user-management-client.service --no-pager || echo "Service Client non trouvé"
echo ""

echo "=== VÉRIFICATION DES PORTS ==="
netstat -tulpn | grep :5000 || echo "Port 5000 non écoute"
netstat -tulpn | grep :8083 || echo "Port 8083 non écoute"
echo ""

echo "=== TEST LOCAL ==="
curl -s http://localhost:5000/health || echo "API locale inaccessible"
echo ""
curl -s http://localhost:8083/health || echo "Client local inaccessible"
echo ""

# Information d'accès
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "=================================================="
echo "Application déployée avec succès!"
echo "API: http://$PUBLIC_IP:5000"
echo "Client: http://$PUBLIC_IP:8083"
echo "Health check API: http://$PUBLIC_IP:5000/health"
echo "Health check Client: http://$PUBLIC_IP:8083/health"
echo "=================================================="

# Script de monitoring
cat > /home/ubuntu/monitor_services.sh << 'EOF'
#!/bin/bash
while true; do
    echo "=== $(date) ==="
    echo "API: $(systemctl is-active user-management-api.service)"
    echo "Client: $(systemctl is-active user-management-client.service)"
    echo "=========================="
    sleep 30
done
EOF

chmod +x /home/ubuntu/monitor_services.sh
nohup /home/ubuntu/monitor_services.sh > /home/ubuntu/service_monitor.log 2>&1 &