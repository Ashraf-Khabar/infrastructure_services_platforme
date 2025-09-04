import pytest
import requests

@pytest.fixture
def api_url():
    """Fixture to provide API base URL"""
    return "http://localhost:5002"

@pytest.fixture
def test_user_data():
    """Fixture to provide test user data"""
    return {
        "username": "testuser",
        "email": "test@example.com",
        "password": "testpassword",
        "first_name": "Test",
        "last_name": "User",
        "role": "user"
    }

@pytest.fixture
def admin_credentials():
    """Fixture to provide admin credentials"""
    return {
        "username": "admin",
        "password": "admin"
    }