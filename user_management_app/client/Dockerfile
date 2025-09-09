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

# Use gunicorn to run the client app (adjust based on your client app structure)
# If your client uses a different entry point, adjust accordingly
CMD ["gunicorn", "--bind", "0.0.0.0:3000", "app:app", "--timeout", "120"]