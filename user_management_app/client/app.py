from flask import Flask, render_template, request, jsonify, redirect, url_for, session, flash
import requests
import os
import hashlib
import logging
from datetime import datetime

# Configurer le logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-secret-key")

# Configuration de l'URL de l'API - CORRIGÉ POUR AWS/DOCKER
IS_DOCKER = os.environ.get('DOCKER', 'false').lower() == 'true'
API_BASE_URL = "http://api:5000" if IS_DOCKER else "http://localhost:5000"
logger.info(f"API Base URL configured: {API_BASE_URL}")
logger.info(f"Docker mode: {IS_DOCKER}")

def get_password_hash(password):
    return hashlib.sha256(password.encode()).hexdigest()

def is_admin():
    return 'user' in session and session['user'].get('role') == 'admin'

def is_authenticated():
    return 'user' in session

# Routes principales
@app.route('/')
def index():
    if not is_authenticated():
        return redirect(url_for('login'))
    return redirect(url_for('dashboard'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if is_authenticated():
        return redirect(url_for('dashboard'))
    
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        try:
            login_data = {"username": username, "password": password}
            logger.info(f"Attempting login to: {API_BASE_URL}/auth/login")
            response = requests.post(f"{API_BASE_URL}/auth/login", json=login_data, timeout=10)
            
            if response.status_code == 200:
                user_data = response.json()
                session['user'] = user_data
                session['login_time'] = datetime.now().isoformat()
                flash('Login successful!', 'success')
                logger.info(f"Login successful for user: {username}")
                return redirect(url_for('dashboard'))
            else:
                logger.warning(f"Login failed for user: {username}, status: {response.status_code}")
                flash('Invalid credentials', 'error')
                
        except requests.exceptions.RequestException as e:
            logger.error(f"API connection error: {e}")
            # Fallback pour l'admin en cas d'urgence
            if username == "admin" and password == "admin":
                admin_user = {
                    "id": 1,
                    "username": "admin",
                    "email": "admin@example.com",
                    "first_name": "Admin",
                    "last_name": "User",
                    "role": "admin",
                    "is_active": True
                }
                session['user'] = admin_user
                session['login_time'] = datetime.now().isoformat()
                flash('Login successful! (Admin fallback mode)', 'success')
                logger.info("Admin fallback login used")
                return redirect(url_for('dashboard'))
            
            flash('API unreachable. Please try again later.', 'error')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out successfully', 'info')
    return redirect(url_for('login'))

@app.route('/dashboard')
def dashboard():
    if not is_authenticated():
        return redirect(url_for('login'))
    
    try:
        logger.info(f"Fetching users from: {API_BASE_URL}/users/")
        users_response = requests.get(f"{API_BASE_URL}/users/", timeout=10)
        users = users_response.json() if users_response.status_code == 200 else []
        
        # Calcul des statistiques
        stats = {
            'total_users': len(users),
            'active_users': len([u for u in users if u.get('is_active', True)]),
            'admin_users': len([u for u in users if u.get('role') == 'admin']),
            'inactive_users': len([u for u in users if not u.get('is_active', True)]),
        }
        
        # Utilisateurs récents (5 derniers)
        recent_users = sorted(users, key=lambda x: x.get('id', 0), reverse=True)[:5]
        
        return render_template('dashboard.html', 
                             user=session['user'], 
                             stats=stats, 
                             recent_users=recent_users,
                             login_time=session.get('login_time'))
    
    except requests.exceptions.RequestException as e:
        logger.error(f"Dashboard API error: {e}")
        return render_template('dashboard.html', 
                             user=session['user'], 
                             stats={}, 
                             recent_users=[],
                             error="API unreachable")

@app.route('/users')
def users_list():
    if not is_authenticated():
        return redirect(url_for('login'))
    
    try:
        response = requests.get(f"{API_BASE_URL}/users/", timeout=10)
        users = response.json() if response.status_code == 200 else []
        return render_template('users.html', users=users, user=session['user'])
    except requests.exceptions.RequestException as e:
        logger.error(f"Users list API error: {e}")
        return render_template('users.html', users=[], error="API unreachable", user=session['user'])

@app.route('/profile')
def profile():
    if not is_authenticated():
        return redirect(url_for('login'))
    return render_template('profile.html', user=session['user'])

@app.route('/reports')
def reports():
    if not is_authenticated():
        return redirect(url_for('login'))
    
    try:
        response = requests.get(f"{API_BASE_URL}/users/", timeout=10)
        users = response.json() if response.status_code == 200 else []
        
        # Génération de rapports
        reports_data = {
            'user_activity': generate_user_activity_report(users),
            'role_distribution': generate_role_distribution(users),
        }
        
        return render_template('reports.html', reports=reports_data, user=session['user'])
    except requests.exceptions.RequestException as e:
        logger.error(f"Reports API error: {e}")
        return render_template('reports.html', reports={}, error="API unreachable", user=session['user'])

@app.route('/settings')
def settings():
    if not is_authenticated():
        return redirect(url_for('login'))
    return render_template('settings.html', user=session['user'])

@app.route('/users', methods=['POST'])
def create_user():
    if not is_authenticated() or not is_admin():
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
        response = requests.post(f"{API_BASE_URL}/users/", json=data, timeout=10)
        if response.status_code == 200:
            flash('User created successfully!', 'success')
            logger.info(f"User created: {data['username']}")
        else:
            error_msg = response.json().get('detail', 'Error creating user')
            flash(f'Error: {error_msg}', 'error')
            logger.error(f"User creation failed: {error_msg}")
    except requests.exceptions.RequestException as e:
        flash('API unreachable, please try again later', 'error')
        logger.error(f"User creation API error: {e}")
    
    return redirect(url_for('users_list'))

@app.route('/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    if not is_authenticated() or not is_admin():
        return jsonify({'success': False, 'error': 'Permission denied'})
    
    try:
        response = requests.delete(f"{API_BASE_URL}/users/{user_id}", timeout=10)
        success = response.status_code == 200
        if success:
            logger.info(f"User deleted: {user_id}")
        return jsonify({'success': success})
    except requests.exceptions.RequestException as e:
        logger.error(f"Delete user API error: {e}")
        return jsonify({'success': False, 'error': 'API unreachable'})

@app.route('/health')
def health_check():
    try:
        # Vérifier la santé de l'API
        api_response = requests.get(f"{API_BASE_URL}/health", timeout=5)
        api_status = api_response.status_code == 200
        
        return jsonify({
            'status': 'healthy' if api_status else 'degraded',
            'api_connected': api_status,
            'timestamp': datetime.now().isoformat()
        })
    except requests.exceptions.RequestException:
        return jsonify({
            'status': 'unhealthy',
            'api_connected': False,
            'timestamp': datetime.now().isoformat()
        }), 500

# Fonctions utilitaires
def generate_user_activity_report(users):
    active_users = len([u for u in users if u.get('is_active', True)])
    inactive_users = len(users) - active_users
    return {
        'active': active_users,
        'inactive': inactive_users,
        'percentage_active': (active_users / len(users) * 100) if users else 0
    }

def generate_role_distribution(users):
    roles = {}
    for user in users:
        role = user.get('role', 'user')
        roles[role] = roles.get(role, 0) + 1
    return roles

if __name__ == '__main__':
    logger.info(f"Starting Flask client on 0.0.0.0:8083")
    logger.info(f"API endpoint: {API_BASE_URL}")
    app.run(host='0.0.0.0', port=8083, debug=False)