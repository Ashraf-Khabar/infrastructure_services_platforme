FROM python:3.9-slim

WORKDIR /app

# Install system dependencies and gunicorn
RUN apt-get update && apt-get install -y \
    gunicorn \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 3000

# Use python to run the client app directly (not gunicorn for client)
# Adjust based on your actual client entry point
CMD ["python", "app.py"]