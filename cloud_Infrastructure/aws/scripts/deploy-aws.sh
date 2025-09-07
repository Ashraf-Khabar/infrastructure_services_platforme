#!/bin/bash
set -e

# Load configuration
source $(dirname "$0")/aws-config.sh

echo "Starting AWS deployment..."
echo "Region: $AWS_REGION"
echo "ECR Registry: $AWS_ECR_REGISTRY"

# Build API image
echo "Building API image..."
cd ${WORKSPACE}/user_management_app/api
docker build -t ${ECR_API_REPOSITORY}:${BUILD_NUMBER} .
docker tag ${ECR_API_REPOSITORY}:${BUILD_NUMBER} ${AWS_ECR_REGISTRY}/${ECR_API_REPOSITORY}:latest

# Build Client image
echo "Building Client image..."
cd ${WORKSPACE}/user_management_app/client
docker build -t ${ECR_CLIENT_REPOSITORY}:${BUILD_NUMBER} .
docker tag ${ECR_CLIENT_REPOSITORY}:${BUILD_NUMBER} ${AWS_ECR_REGISTRY}/${ECR_CLIENT_REPOSITORY}:latest

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ECR_REGISTRY}

# Push images
echo "Pushing images to ECR..."
docker push ${AWS_ECR_REGISTRY}/${ECR_API_REPOSITORY}:latest
docker push ${AWS_ECR_REGISTRY}/${ECR_CLIENT_REPOSITORY}:latest

# Deploy to ECS
echo "Deploying to ECS..."
aws ecs update-service \
    --cluster ${ECS_CLUSTER} \
    --service ${ECS_SERVICE} \
    --force-new-deployment \
    --region ${AWS_REGION}

echo "Deployment completed successfully!"
echo "Service update initiated. Check ECS console for status."