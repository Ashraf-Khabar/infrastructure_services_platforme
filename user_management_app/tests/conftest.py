import pytest
import requests

@pytest.fixture
def api_url():
    return "http://localhost:5002"

@pytest.fixture
def admin_credentials():
    return {
        "username": "admin",
        "password": "admin"
    }