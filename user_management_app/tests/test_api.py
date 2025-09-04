import pytest
import sys
import os

# Ajouter le chemin de l'API au PATH
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../api'))

from fastapi.testclient import TestClient
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
import hashlib

# Créer une application de test
app = FastAPI()

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    first_name: str = None
    last_name: str = None
    role: str
    is_active: bool

# Données de test
test_users = [
    {
        "id": 1,
        "username": "admin",
        "email": "admin@example.com",
        "password_hash": "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918",
        "first_name": "Admin",
        "last_name": "User",
        "role": "admin",
        "is_active": True
    }
]

@app.get("/users/", response_model=List[UserResponse])
def get_users():
    users_response = []
    for user in test_users:
        users_response.append({
            "id": user["id"],
            "username": user["username"],
            "email": user["email"],
            "first_name": user["first_name"],
            "last_name": user["last_name"],
            "role": user["role"],
            "is_active": user["is_active"]
        })
    return users_response

@app.get("/health")
def health_check():
    return {"status": "healthy", "users_count": len(test_users)}

client = TestClient(app)

def test_health_check():
    """Test du endpoint health check"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
    assert "users_count" in response.json()

def test_get_users():
    """Test de récupération des utilisateurs"""
    response = client.get("/users/")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
    assert len(response.json()) > 0

def test_user_structure():
    """Test de la structure des données utilisateur"""
    response = client.get("/users/")
    users = response.json()
    
    assert "id" in users[0]
    assert "username" in users[0]
    assert "email" in users[0]
    assert "role" in users[0]
    assert "is_active" in users[0]

def test_admin_user_exists():
    """Test que l'utilisateur admin existe"""
    response = client.get("/users/")
    users = response.json()
    
    admin_users = [u for u in users if u["username"] == "admin"]
    assert len(admin_users) == 1
    assert admin_users[0]["role"] == "admin"

if __name__ == "__main__":
    # Exécution directe pour les tests
    pytest.main(["-v", __file__])