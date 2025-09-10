FROM tiangolo/uvicorn-gunicorn-fastapi:python3.11

WORKDIR /app

COPY requirements.txt .

# Install additional dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# The base image already has the CMD set up for FastAPI