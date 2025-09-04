import pytest
import requests
import hashlib

# Tests d'API simples qui utilisent requests au lieu de TestClient

def test_api_root():
    """Test the root endpoint"""
    try:
        response = requests.get("http://localhost:5002/", timeout=5)
        assert response.status_code == 200
        assert response.json()["message"] == "User Management API is running"
    except requests.exceptions.ConnectionError:
        pytest.skip("API not running")

def test_api_health():
    """Test the health check endpoint"""
    try:
        response = requests.get("http://localhost:5002/health", timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
    except requests.exceptions.ConnectionError:
        pytest.skip("API not running")

def test_get_users():
    """Test getting users list"""
    try:
        response = requests.get("http://localhost:5002/users/", timeout=5)
        assert response.status_code == 200
        users = response.json()
        assert isinstance(users, list)
        # Vérifier que l'utilisateur admin existe
        admin_user = next((u for u in users if u['username'] == 'admin'), None)
        assert admin_user is not None
    except requests.exceptions.ConnectionError:
        pytest.skip("API not running")

def test_create_user():
    """Test creating a new user"""
    try:
        user_data = {
            "username": "testuser",
            "email": "test@example.com",
            "password": "testpassword",
            "first_name": "Test",
            "last_name": "User",
            "role": "user"
        }
        
        response = requests.post("http://localhost:5002/users/", json=user_data, timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "testuser"
        assert data["email"] == "test@example.com"
    except requests.exceptions.ConnectionError:
        pytest.skip("API not running")

def test_login_success():
    """Test successful login"""
    try:
        login_data = {
            "username": "admin",
            "password": "admin"
        }
        
        response = requests.post("http://localhost:5002/auth/login", json=login_data, timeout=5)
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "admin"
        assert data["role"] == "admin"
    except requests.exceptions.ConnectionError:
        pytest.skip("API not running")

def test_login_failure():
    """Test failed login"""
    try:
        login_data = {
            "username": "nonexistent",
            "password": "wrongpassword"
        }
        
        response = requests.post("http://localhost:5002/auth/login", json=login_data, timeout=5)
        assert response.status_code == 401
    except requests.exceptions.ConnectionError:
        pytest.skip("API not running")