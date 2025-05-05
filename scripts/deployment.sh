#!/bin/bash
set -e

# Configuration
AWS_REGION="eu-west-1"
APP_NAME="birthday-app"
IMAGE_TAG=$(date +%Y%m%d%H%M%S)
CLUSTER_NAME="birthday-app-cluster"
SERVICE_NAME="birthday-app-service"

# Get ECR repository URL from Terraform output
ECR_REPO=$(terraform output -state=./terraform/terraform.tfstate -raw ecr_repository_url)

# Build the Docker image (amd64)
echo "Building Docker image..."
docker buildx build --platform linux/amd64 -t "${APP_NAME}:${IMAGE_TAG}" .

# Log in to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}

# Tag and push the image
echo "Tagging and pushing the image to ECR..."
docker tag ${APP_NAME}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
docker tag ${APP_NAME}:${IMAGE_TAG} ${ECR_REPO}:latest
docker push ${ECR_REPO}:${IMAGE_TAG}
docker push ${ECR_REPO}:latest

# Create a new task definition revision
echo "Creating new task definition revision..."
TASK_DEFINITION_ARN=$(aws ecs describe-services --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --region ${AWS_REGION} --query 'services[0].taskDefinition' --output text)
TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition ${TASK_DEFINITION_ARN} --region ${AWS_REGION})

# Update the image in the task definition
NEW_TASK_DEFINITION=$(echo $TASK_DEFINITION | jq --arg IMAGE "${ECR_REPO}:${IMAGE_TAG}" '.taskDefinition | .containerDefinitions[0].image = $IMAGE | {containerDefinitions: .containerDefinitions, family: .family, taskRoleArn: .taskRoleArn, executionRoleArn: .executionRoleArn, networkMode: .networkMode, volumes: .volumes, placementConstraints: .placementConstraints, requiresCompatibilities: .requiresCompatibilities, cpu: .cpu, memory: .memory}')

# Register the new task definition
echo "Registering new task definition..."
NEW_TASK_DEFINITION_ARN=$(aws ecs register-task-definition --region ${AWS_REGION} --cli-input-json "$NEW_TASK_DEFINITION" --query 'taskDefinition.taskDefinitionArn' --output text)

# Update the service to use the new task definition
echo "Updating ECS service with new task definition..."
aws ecs update-service --cluster ${CLUSTER_NAME} --service ${SERVICE_NAME} --task-definition ${NEW_TASK_DEFINITION_ARN} --region ${AWS_REGION}

# Monitor deployment status
echo "Monitoring deployment status..."
aws ecs wait services-stable --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION}

echo "Deployment completed successfully!"
echo "Service is now running with new image: ${ECR_REPO}:${IMAGE_TAG}"

# Check the health of deployed service
LOAD_BALANCER_DNS=$(terraform output -state=./terraform/terraform.tfstate -raw alb_dns_name)
echo "Testing service health at http://${LOAD_BALANCER_DNS}/health"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${LOAD_BALANCER_DNS}/health)

if [ $HTTP_STATUS -eq 200 ]; then
    echo "Service is healthy (HTTP ${HTTP_STATUS})"
    echo "Zero-downtime deployment completed successfully!"
else
    echo "Warning: Service returned HTTP ${HTTP_STATUS}. You may want to investigate."
fi
