import hashlib

def test_password_hashing():
    """Test password hashing and verification"""
    def get_password_hash(password):
        return hashlib.sha256(password.encode()).hexdigest()
    
    def verify_password(plain_password, hashed_password):
        return get_password_hash(plain_password) == hashed_password
    
    password = "testpassword"
    hashed = get_password_hash(password)
    
    # Should verify correctly
    assert verify_password(password, hashed) == True
    
    # Should fail with wrong password
    assert verify_password("wrongpassword", hashed) == False

def test_password_hash_consistency():
    """Test that the same password produces the same hash"""
    def get_password_hash(password):
        return hashlib.sha256(password.encode()).hexdigest()
    
    password = "consistentpassword"
    hash1 = get_password_hash(password)
    hash2 = get_password_hash(password)
    
    assert hash1 == hash2

def test_admin_password_hash():
    """Test that admin password hash is correct"""
    def get_password_hash(password):
        return hashlib.sha256(password.encode()).hexdigest()
    
    admin_password = "admin"
    expected_hash = "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918"
    
    assert get_password_hash(admin_password) == expected_hash