from flask import Flask, render_template, request, jsonify, redirect, url_for, session, flash
import requests
import os
import hashlib
import logging

# Configurer le logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-secret-key")

# Déterminer l'URL de l'API en fonction de l'environnement
IS_DOCKER = os.environ.get('DOCKER', 'false').lower() == 'true'
API_URL = "http://user-management-api:5000" if IS_DOCKER else "http://localhost:5002"

logger.info(f"API URL: {API_URL}")

def get_password_hash(password):
    return hashlib.sha256(password.encode()).hexdigest()

def is_admin():
    """Vérifier si l'utilisateur connecté est un admin"""
    return 'user' in session and session['user'].get('role') == 'admin'

@app.route('/')
def index():
    if 'user' not in session:
        return redirect(url_for('login'))
    return redirect(url_for('dashboard'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        try:
            # Essayer d'abord le nouvel endpoint d'authentification
            login_data = {
                "username": username,
                "password": password
            }
            
            response = requests.post(f"{API_URL}/auth/login", json=login_data, timeout=10)
            
            if response.status_code == 200:
                user_data = response.json()
                session['user'] = user_data
                flash('Login successful!', 'success')
                return redirect(url_for('dashboard'))
            else:
                error_msg = response.json().get('detail', 'Invalid credentials')
                flash(error_msg, 'error')
                
        except requests.exceptions.RequestException as e:
            logger.error(f"API connection error: {e}")
            
            # Fallback: vérification manuelle pour l'admin
            if username == "admin" and password == "admin":
                try:
                    # Récupérer les infos de l'utilisateur admin
                    users_response = requests.get(f"{API_URL}/users/", timeout=10)
                    if users_response.status_code == 200:
                        users = users_response.json()
                        admin_user = next((u for u in users if u['username'] == "admin"), None)
                        
                        if admin_user:
                            session['user'] = admin_user
                            flash('Login successful! (Fallback mode)', 'success')
                            return redirect(url_for('dashboard'))
                except requests.exceptions.RequestException:
                    pass
            
            flash('API unreachable. Please check if the API server is running.', 'error')
    
    return render_template('login.html')

@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect(url_for('login'))
    
    try:
        users_response = requests.get(f"{API_URL}/users/", timeout=10)
        users = users_response.json() if users_response.status_code == 200 else []
        
        stats = {
            'total_users': len(users),
            'active_users': len([u for u in users if u['is_active']]),
            'admin_users': len([u for u in users if u['role'] == 'admin'])
        }
        
        return render_template('dashboard.html', user=session['user'], stats=stats, users=users[:5])
    except requests.exceptions.RequestException as e:
        logger.error(f"Dashboard error: {e}")
        # Utiliser des données factices pour le dashboard en mode dégradé
        stats = {
            'total_users': 1,
            'active_users': 1,
            'admin_users': 1
        }
        return render_template('dashboard.html', user=session['user'], stats=stats, users=[], error="API unreachable - showing demo data")

@app.route('/users')
def users_list():
    if 'user' not in session:
        return redirect(url_for('login'))
    
    try:
        response = requests.get(f"{API_URL}/users/", timeout=10)
        users = response.json() if response.status_code == 200 else []
        return render_template('users.html', users=users, user=session['user'])
    except requests.exceptions.RequestException as e:
        logger.error(f"Users list error: {e}")
        return render_template('users.html', users=[], error="API unreachable", user=session['user'])

@app.route('/users', methods=['POST'])
def create_user():
    if 'user' not in session:
        return redirect(url_for('login'))
    
    # Vérifier les permissions
    if not is_admin():
        flash('Permission denied. Only administrators can create users.', 'error')
        return redirect(url_for('users_list'))
    
    data = {
        'username': request.form['username'],
        'email': request.form['email'],
        'password': request.form['password'],
        'first_name': request.form.get('first_name', ''),
        'last_name': request.form.get('last_name', ''),
        'role': request.form.get('role', 'user')
    }
    
    try:
        response = requests.post(f"{API_URL}/users/", json=data, timeout=10)
        if response.status_code == 200:
            flash('User created successfully!', 'success')
            return redirect(url_for('users_list'))
        else:
            error_msg = response.json().get('detail', 'Error creating user')
            flash(f'Error: {error_msg}', 'error')
            return redirect(url_for('users_list'))
    except requests.exceptions.RequestException as e:
        logger.error(f"Create user error: {e}")
        flash('API unreachable, please try again later', 'error')
        return redirect(url_for('users_list'))

@app.route('/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    if 'user' not in session:
        return jsonify({'success': False, 'error': 'Not authenticated'})
    
    # Vérifier les permissions
    if not is_admin():
        return jsonify({'success': False, 'error': 'Permission denied'})
    
    try:
        response = requests.delete(f"{API_URL}/users/{user_id}", timeout=10)
        return jsonify({'success': response.status_code == 200})
    except requests.exceptions.RequestException as e:
        logger.error(f"Delete user error: {e}")
        return jsonify({'success': False, 'error': 'API unreachable'})

@app.route('/logout')
def logout():
    session.pop('user', None)
    flash('You have been logged out', 'info')
    return redirect(url_for('login'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8083, debug=True)