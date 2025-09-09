FROM python:3.9-slim

WORKDIR /app

# Install system dependencies and gunicorn
RUN apt-get update && apt-get install -y \
    gunicorn \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

# Use gunicorn to run the Flask app - FIXED COMMAND
# Make sure your Flask app instance is named 'app' in app.py
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app", "--timeout", "120", "--access-logfile", "-"]