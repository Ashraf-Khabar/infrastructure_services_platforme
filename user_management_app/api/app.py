from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import hashlib
import logging

# Configurer le logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP Requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])
ACTIVE_USERS = Gauge('user_management_active_users', 'Number of active users')

app = FastAPI(
    title="User Management API", 
    version="1.0.0",
    description="API for managing users with authentication"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8083", "http://client:8083"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class UserCreate(BaseModel):
    username: str
    email: str
    password: str
    first_name: str = None
    last_name: str = None
    role: str = "user"

class LoginRequest(BaseModel):
    username: str
    password: str

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    first_name: str = None
    last_name: str = None
    role: str
    is_active: bool

# Données utilisateur en mémoire pour le test
users_db = [
    {
        "id": 1,
        "username": "admin",
        "email": "admin@example.com",
        "password_hash": "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918",  # admin
        "first_name": "Admin",
        "last_name": "User",
        "role": "admin",
        "is_active": True
    }
]

def get_password_hash(password):
    return hashlib.sha256(password.encode()).hexdigest()

def verify_password(plain_password, hashed_password):
    return get_password_hash(plain_password) == hashed_password


@app.middleware("http")
async def monitor_requests(request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(process_time)
    
    return response

@app.get('/metrics')
async def metrics():
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )

@app.get("/")
def read_root():
    logger.info("Root endpoint called")
    return {"message": "User Management API is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "users_count": len(users_db)}

@app.post("/auth/login")
def login(login_data: LoginRequest):
    logger.info(f"Login attempt for user: {login_data.username}")
    
    user = next((u for u in users_db if u["username"] == login_data.username), None)
    
    if not user:
        logger.warning(f"User not found: {login_data.username}")
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    if not verify_password(login_data.password, user["password_hash"]):
        logger.warning(f"Invalid password for user: {login_data.username}")
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    # Retourner les infos utilisateur sans le mot de passe
    user_response = {
        "id": user["id"],
        "username": user["username"],
        "email": user["email"],
        "first_name": user["first_name"],
        "last_name": user["last_name"],
        "role": user["role"],
        "is_active": user["is_active"]
    }
    
    logger.info(f"Login successful for user: {login_data.username}")
    return user_response

@app.get("/users/", response_model=List[UserResponse])
def get_users():
    logger.info("Get users endpoint called")
    # Retourner les utilisateurs sans le mot de passe hash
    users_response = []
    for user in users_db:
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

@app.post("/users/", response_model=UserResponse)
def create_user(user: UserCreate):
    logger.info(f"Create user attempt: {user.username}")
    
    # Vérifier si l'utilisateur existe déjà
    existing_user = next((u for u in users_db if u["username"] == user.username or u["email"] == user.email), None)
    if existing_user:
        logger.warning(f"User already exists: {user.username}")
        raise HTTPException(status_code=400, detail="Username or email already exists")
    
    new_id = max([u["id"] for u in users_db]) + 1 if users_db else 1
    
    new_user = {
        "id": new_id,
        "username": user.username,
        "email": user.email,
        "password_hash": get_password_hash(user.password),
        "first_name": user.first_name,
        "last_name": user.last_name,
        "role": user.role,
        "is_active": True
    }
    
    users_db.append(new_user)
    
    user_response = {
        "id": new_user["id"],
        "username": new_user["username"],
        "email": new_user["email"],
        "first_name": new_user["first_name"],
        "last_name": new_user["last_name"],
        "role": new_user["role"],
        "is_active": new_user["is_active"]
    }
    
    logger.info(f"User created successfully: {user.username}")
    return user_response

@app.delete("/users/{user_id}")
def delete_user(user_id: int):
    logger.info(f"Delete user attempt: {user_id}")
    
    user_index = next((i for i, u in enumerate(users_db) if u["id"] == user_id), None)
    
    if user_index is None:
        logger.warning(f"User not found for deletion: {user_id}")
        raise HTTPException(status_code=404, detail="User not found")
    
    deleted_user = users_db.pop(user_index)
    logger.info(f"User deleted: {deleted_user['username']}")
    
    return {"message": "User deleted successfully"}

if __name__ == "__main__":
    import uvicorn
    logger.info("Starting API server on 0.0.0.0:5000")
    uvicorn.run(app, host="0.0.0.0", port=5000, log_level="info")