from flask import Flask, render_template, request, jsonify, redirect, url_for, session, flash
import requests
import os
import hashlib
import logging
from datetime import datetime, timedelta

# Configurer le logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-secret-key")

# Déterminer l'URL de l'API
IS_DOCKER = os.environ.get('DOCKER', 'false').lower() == 'true'
API_URL = "http://52.45.14.171:5000/health" if IS_DOCKER else "http://localhost:5002"

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
            response = requests.post(f"{API_URL}/auth/login", json=login_data, timeout=10)
            
            if response.status_code == 200:
                user_data = response.json()
                session['user'] = user_data
                session['login_time'] = datetime.now().isoformat()
                flash('Login successful!', 'success')
                return redirect(url_for('dashboard'))
            else:
                flash('Invalid credentials', 'error')
                
        except requests.exceptions.RequestException:
            # Fallback pour l'admin
            if username == "admin" and password == "admin":
                try:
                    users_response = requests.get(f"{API_URL}/users/", timeout=10)
                    if users_response.status_code == 200:
                        users = users_response.json()
                        admin_user = next((u for u in users if u['username'] == "admin"), None)
                        if admin_user:
                            session['user'] = admin_user
                            session['login_time'] = datetime.now().isoformat()
                            flash('Login successful! (Fallback mode)', 'success')
                            return redirect(url_for('dashboard'))
                except requests.exceptions.RequestException:
                    pass
            
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
        users_response = requests.get(f"{API_URL}/users/", timeout=10)
        users = users_response.json() if users_response.status_code == 200 else []
        
        # Calcul des statistiques
        stats = {
            'total_users': len(users),
            'active_users': len([u for u in users if u.get('is_active', True)]),
            'admin_users': len([u for u in users if u.get('role') == 'admin']),
            'inactive_users': len([u for u in users if not u.get('is_active', True)]),
            'recent_users': len([u for u in users if datetime.fromisoformat(u.get('created_at', '2000-01-01')).date() == datetime.now().date()])
        }
        
        # Utilisateurs récents (5 derniers)
        recent_users = sorted(users, key=lambda x: x.get('created_at', ''), reverse=True)[:5]
        
        return render_template('dashboard.html', 
                             user=session['user'], 
                             stats=stats, 
                             recent_users=recent_users,
                             login_time=session.get('login_time'))
    
    except requests.exceptions.RequestException:
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
        response = requests.get(f"{API_URL}/users/", timeout=10)
        users = response.json() if response.status_code == 200 else []
        return render_template('users.html', users=users, user=session['user'])
    except requests.exceptions.RequestException:
        return render_template('users.html', users=[], error="API unreachable", user=session['user'])

# Nouvelles fonctionnalités
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
        response = requests.get(f"{API_URL}/users/", timeout=10)
        users = response.json() if response.status_code == 200 else []
        
        # Génération de rapports
        reports_data = {
            'user_activity': generate_user_activity_report(users),
            'role_distribution': generate_role_distribution(users),
            'registration_trends': generate_registration_trends(users)
        }
        
        return render_template('reports.html', reports=reports_data, user=session['user'])
    except requests.exceptions.RequestException:
        return render_template('reports.html', reports={}, error="API unreachable", user=session['user'])

@app.route('/settings')
def settings():
    if not is_authenticated():
        return redirect(url_for('login'))
    return render_template('settings.html', user=session['user'])

@app.route('/users/toggle/<int:user_id>', methods=['POST'])
def toggle_user_status(user_id):
    if not is_authenticated() or not is_admin():
        return jsonify({'success': False, 'error': 'Permission denied'})
    
    try:
        response = requests.get(f"{API_URL}/users/{user_id}", timeout=10)
        if response.status_code == 200:
            user_data = response.json()
            updated_data = {'is_active': not user_data.get('is_active', True)}
            
            update_response = requests.put(f"{API_URL}/users/{user_id}", json=updated_data, timeout=10)
            return jsonify({'success': update_response.status_code == 200})
    except requests.exceptions.RequestException:
        pass
    
    return jsonify({'success': False, 'error': 'API unreachable'})

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

def generate_registration_trends(users):
    # Simuler des données de tendances (dans une vraie app, utiliser les dates réelles)
    return {
        'last_7_days': [5, 8, 6, 10, 7, 12, 9],
        'last_30_days': [45, 52, 48, 55, 60, 58, 62, 65, 70, 68, 72, 75, 78, 80]
    }

# Gestion des utilisateurs (existante)
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
        response = requests.post(f"{API_URL}/users/", json=data, timeout=10)
        if response.status_code == 200:
            flash('User created successfully!', 'success')
        else:
            error_msg = response.json().get('detail', 'Error creating user')
            flash(f'Error: {error_msg}', 'error')
    except requests.exceptions.RequestException:
        flash('API unreachable, please try again later', 'error')
    
    return redirect(url_for('users_list'))

@app.route('/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    if not is_authenticated() or not is_admin():
        return jsonify({'success': False, 'error': 'Permission denied'})
    
    try:
        response = requests.delete(f"{API_URL}/users/{user_id}", timeout=10)
        return jsonify({'success': response.status_code == 200})
    except requests.exceptions.RequestException:
        return jsonify({'success': False, 'error': 'API unreachable'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8083, debug=True)