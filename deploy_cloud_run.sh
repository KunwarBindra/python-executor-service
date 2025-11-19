#!/bin/bash

# Deployment script for Google Cloud Run
# Usage: ./deploy_cloud_run.sh [PROJECT_ID] [SERVICE_NAME] [REGION]

# Default values
PROJECT_ID=${1:-"your-project-id"}
SERVICE_NAME=${2:-"python-executor"}
REGION=${3:-"us-central1"}

echo "Deploying Python Executor Service to Google Cloud Run"
echo "======================================================"
echo "Project ID: $PROJECT_ID"
echo "Service Name: $SERVICE_NAME"
echo "Region: $REGION"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install it first."
    exit 1
fi

# Configure Docker for GCR
echo "Configuring Docker for Google Container Registry..."
gcloud auth configure-docker

# Build the Docker image
echo "Building Docker image..."
docker build -t gcr.io/$PROJECT_ID/$SERVICE_NAME .

if [ $? -ne 0 ]; then
    echo "Error: Docker build failed"
    exit 1
fi

# Push to Google Container Registry
echo "Pushing image to Google Container Registry..."
docker push gcr.io/$PROJECT_ID/$SERVICE_NAME

if [ $? -ne 0 ]; then
    echo "Error: Docker push failed"
    exit 1
fi

# Deploy to Cloud Run
echo "Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --timeout 60 \
  --max-instances 10 \
  --project $PROJECT_ID

if [ $? -ne 0 ]; then
    echo "Error: Cloud Run deployment failed"
    exit 1
fi

# Get the service URL
echo ""
echo "Deployment successful!"
echo "Getting service URL..."
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID --format 'value(status.url)')

echo ""
echo "======================================================"
echo "Service deployed successfully!"
echo "Service URL: $SERVICE_URL"
echo ""
echo "Test the service with:"
echo "curl -X POST $SERVICE_URL/execute \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"script\": \"def main():\\n    return {\\\"message\\\": \\\"Hello from Cloud Run!\\\", \\\"status\\\": \\\"success\\\"}\"}'"
echo ""
echo "Health check:"
echo "curl $SERVICE_URL/health"
echo "======================================================"

