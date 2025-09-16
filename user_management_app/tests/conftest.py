import pytest
import requests

@pytest.fixture
def api_url():
    return "http://localhost:5002"

@pytest.fixture
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
    return {
        "username": "admin",
        "password": "admin"
    }