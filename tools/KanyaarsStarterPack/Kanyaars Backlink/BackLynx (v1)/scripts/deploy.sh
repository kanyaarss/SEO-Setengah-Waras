#!/bin/bash

# BackLynx Deployment Script
echo "Starting BackLynx deployment..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed."
    exit 1
fi

# Create necessary directories
mkdir -p data/results data/logs data/models

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp .env.example .env
    echo "Please edit .env file with your configuration before continuing."
    echo "Especially set your OPENAI_API_KEY if using AI features."
    read -p "Press Enter after editing .env file..."
fi

# Build and start services
echo "Building Docker images..."
docker-compose build

echo "Starting services..."
docker-compose up -d

# Wait for services to start
echo "Waiting for services to initialize..."
sleep 30

# Check service health
echo "Checking service health..."
docker-compose ps

# Show logs
echo "Showing recent logs..."
docker-compose logs --tail=50

echo "Deployment complete!"
echo "Access the API at: http://localhost:8080"
echo "Check logs with: docker-compose logs -f"
echo "Stop services with: docker-compose down"
