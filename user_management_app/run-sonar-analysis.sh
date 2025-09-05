#!/bin/bash

echo "Installing dependencies..."
pip install -r api/requirements.txt
pip install -r tests/requirements.txt

echo "Running tests with coverage..."
python -m pytest tests/ --cov=api --cov=shared --cov-report=xml:coverage.xml --junitxml=test-results.xml

echo "Waiting for SonarQube to be ready..."
until curl -s http://sonar.host.internal/api/system/status | grep -q '"status":"UP"'; do
  echo "SonarQube not ready, waiting..."
  sleep 10
done

echo "Running SonarQube analysis..."
docker-compose run --rm sonar-scanner