#!/bin/bash

# Mise à jour et installation
apt-get update -y
apt-get upgrade -y
apt-get install -y python3 python3-pip git

# Clonez votre application depuis le workspace Jenkins
echo "Copie de l'application depuis le workspace Jenkins..."
# Cette partie sera exécutée par Jenkins lors du déploiement

# Création des répertoires
mkdir -p /home/ubuntu/user_management_app
cd /home/ubuntu/user_management_app

# Si l'application n'est pas copiée, créez une structure minimale
if [ ! -f "docker-compose.yml" ]; then
    echo "Création d'une structure d'application basique..."
    
    # Copiez votre application existante ou créez une structure minimale
    # Pour l'instant, créons une structure basique
    mkdir -p api client/templates client/static/css client/static/js
    
    # API minimale
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

    cat > api/requirements.txt << 'EOF'
flask==2.3.3
EOF

    # Client minimal avec interface
    cat > client/app.py << 'EOF'
from flask import Flask, jsonify, render_template
import requests
app = Flask(__name__)

@app.route('/')
def home():
    try:
        response = requests.get('http://localhost:5000/api/users', timeout=2)
        users_data = response.json() if response.status_code == 200 else {"users": []}
    except:
        users_data = {"users": []}
    
    return render_template('index.html', 
                         message="User Management System",
                         users=users_data.get('users', []),
                         api_status="connected" if users_data else "disconnected")

@app.route('/health')
def health():
    try:
        response = requests.get('http://localhost:5000/health', timeout=2)
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

    cat > client/requirements.txt << 'EOF'
flask==2.3.3
requests==2.31.0
EOF

    # Template HTML basique
    mkdir -p client/templates
    cat > client/templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>User Management System</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .connected { background: #d4edda; color: #155724; }
        .disconnected { background: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <div class="container">
        <h1>User Management System</h1>
        <div class="status {% if api_status == 'connected' %}connected{% else %}disconnected{% endif %}">
            API Status: {{ api_status }}
        </div>
        <h2>Users ({{ users|length }})</h2>
        {% if users %}
            <ul>
            {% for user in users %}
                <li>{{ user.name|default('Unknown') }} - {{ user.email|default('No email') }}</li>
            {% endfor %}
            </ul>
        {% else %}
            <p>No users found or API unavailable</p>
        {% endif %}
    </div>
</body>
</html>
EOF
fi

# Installation des dépendances
pip3 install -r api/requirements.txt
pip3 install -r client/requirements.txt

# Création des services systemd
cat > /etc/systemd/system/user-management-api.service << 'EOF'
[Unit]
Description=User Management API Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/user_management_app/api
ExecStart=/usr/bin/python3 app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/user-management-client.service << 'EOF'
[Unit]
Description=User Management Client Service
After=network.target user-management-api.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/user_management_app/client
ExecStart=/usr/bin/python3 app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Démarrage des services
systemctl daemon-reload
systemctl enable user-management-api.service
systemctl enable user-management-client.service
systemctl start user-management-api.service
systemctl start user-management-client.service

# Vérification
echo "Attente du démarrage..."
sleep 10
echo "=== STATUS ==="
systemctl status user-management-api.service --no-pager
echo ""
systemctl status user-management-client.service --no-pager
echo ""
echo "=== PORTS ==="
netstat -tulpn | grep :5000 || echo "Port 5000 not listening"
netstat -tulpn | grep :8083 || echo "Port 8083 not listening"
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