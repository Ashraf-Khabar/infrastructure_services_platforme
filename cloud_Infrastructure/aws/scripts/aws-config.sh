#!/bin/bash
# Configuration AWS
export AWS_REGION="us-east-1"
export AWS_ECR_REGISTRY="your-account-id.dkr.ecr.${AWS_REGION}.amazonaws.com"
export ECR_API_REPOSITORY="user-management-api"
export ECR_CLIENT_REPOSITORY="user-management-client"
export ECS_CLUSTER="user-management-cluster"
export ECS_SERVICE="user-management-service"

# Database configuration (à remplacer par vos vraies valeurs après le déploiement Terraform)
export DATABASE_URL="postgresql://username:password@db-endpoint:5432/dbname"

# Logging
export AWS_LOG_GROUP="/ecs/user-management-app"