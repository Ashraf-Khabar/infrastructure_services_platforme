#!/bin/bash

# Mise à jour et installation des dépendances système
apt-get update -y
apt-get upgrade -y
apt-get install -y python3 python3-pip python3-venv

# Création du répertoire de l'application
mkdir -p /home/ubuntu/user_management_app
cd /home/ubuntu/user_management_app

# Installation des dépendances Python de base pour l'application
# (Ces dépendances devraient correspondre à vos fichiers requirements.txt)

# Dépendances pour l'API
pip3 install flask==2.3.3 flask-cors==4.0.0 python-dotenv==1.0.0 gunicorn==21.2.0

# Dépendances pour le Client
pip3 install flask==2.3.3 requests==2.31.0

# Création des services systemd - ils attendront que l'application soit copiée
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
Environment=PYTHONUNBUFFERED=1

# Attendre que l'application soit copiée
ExecStartPre=/bin/sleep 10
ExecStartPre=/bin/bash -c "while [ ! -f /home/ubuntu/user_management_app/api/app.py ]; do echo 'En attente de l application API...'; sleep 5; done"

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
Environment=PYTHONUNBUFFERED=1

# Attendre que l'application soit copiée
ExecStartPre=/bin/sleep 10
ExecStartPre=/bin/bash -c "while [ ! -f /home/ubuntu/user_management_app/client/app.py ]; do echo 'En attente de l application Client...'; sleep 5; done"

[Install]
WantedBy=multi-user.target
EOF

# Activation des services (ils ne démarreront pas tant que l'application n'est pas copiée)
systemctl daemon-reload
systemctl enable user-management-api.service
systemctl enable user-management-client.service

echo "=================================================="
echo "✅ Environnement préparé avec succès!"
echo "📁 Répertoire: /home/ubuntu/user_management_app"
echo "🔧 Services systemd configurés et activés"
echo "⏳ En attente de la copie de l'application..."
echo "=================================================="

# Script pour vérifier l'état de l'application
cat > /home/ubuntu/check_app_status.sh << 'EOF'
#!/bin/bash
echo "=== Vérification de l'application ==="
echo "Répertoire API: $(ls -la /home/ubuntu/user_management_app/api/ 2>/dev/null || echo 'Non trouvé')"
echo "Répertoire Client: $(ls -la /home/ubuntu/user_management_app/client/ 2>/dev/null || echo 'Non trouvé')"
echo "Fichier API app.py: $( [ -f /home/ubuntu/user_management_app/api/app.py ] && echo '✅ Présent' || echo '❌ Absent' )"
echo "Fichier Client app.py: $( [ -f /home/ubuntu/user_management_app/client/app.py ] && echo '✅ Présent' || echo '❌ Absent' )"
echo "====================================="
EOF

chmod +x /home/ubuntu/check_app_status.sh

# Information d'accès
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "🌐 IP Publique: $PUBLIC_IP"
echo "🚀 Une fois l'application copiée, elle sera accessible sur:"
echo "   - API: http://$PUBLIC_IP:5000"
echo "   - Client: http://$PUBLIC_IP:8083"