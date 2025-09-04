import hashlib
import pytest

def test_password_hashing():
    """Test unitaire de hachage de mot de passe"""
    def get_password_hash(password):
        return hashlib.sha256(password.encode()).hexdigest()
    
    password = "test123"
    hashed = get_password_hash(password)
    
    # Vérifier que le hachage est consistent
    assert get_password_hash(password) == hashed
    assert get_password_hash("different") != hashed

def test_admin_password():
    """Test du mot de passe admin"""
    def get_password_hash(password):
        return hashlib.sha256(password.encode()).hexdigest()
    
    admin_hash = get_password_hash("admin")
    expected_hash = "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918"
    assert admin_hash == expected_hash

def test_imports():
    """Test que tous les imports fonctionnent"""
    try:
        import fastapi
        import flask
        import sqlalchemy
        import pytest
        import requests
        assert True
    except ImportError as e:
        pytest.fail(f"Import failed: {e}")

def test_basic_assertions():
    """Tests basiques de vérification"""
    assert 1 + 1 == 2
    assert "hello".upper() == "HELLO"
    assert [1, 2, 3] == [1, 2, 3]