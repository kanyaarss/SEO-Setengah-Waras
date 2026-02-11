#!/bin/bash

# BackLynx Health Check Script
echo "Performing BackLynx health check..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Redis
echo -n "Checking Redis... "
if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
    REDIS_STATUS=0
else
    echo -e "${RED}FAILED${NC}"
    REDIS_STATUS=1
fi

# Check Go Orchestrator
echo -n "Checking Go Orchestrator... "
if curl -f http://localhost:8080/api/v1/status > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
    GO_STATUS=0
else
    echo -e "${RED}FAILED${NC}"
    GO_STATUS=1
fi

# Check Python AI Service
echo -n "Checking Python AI Service... "
if curl -f http://localhost:5000/health > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
    PYTHON_STATUS=0
else
    echo -e "${RED}FAILED${NC}"
    PYTHON_STATUS=1
fi

# Check Docker containers
echo -n "Checking Docker containers... "
CONTAINER_COUNT=$(docker-compose ps -q | wc -l)
if [ $CONTAINER_COUNT -gt 0 ]; then
    echo -e "${GREEN}OK ($CONTAINER_COUNT containers running)${NC}"
    CONTAINER_STATUS=0
else
    echo -e "${RED}FAILED (no containers running)${NC}"
    CONTAINER_STATUS=1
fi

# Overall status
echo ""
echo "=== Health Check Summary ==="
if [ $REDIS_STATUS -eq 0 ] && [ $GO_STATUS -eq 0 ] && [ $PYTHON_STATUS -eq 0 ] && [ $CONTAINER_STATUS -eq 0 ]; then
    echo -e "${GREEN}All services are healthy!${NC}"
    exit 0
else
    echo -e "${RED}Some services are not healthy!${NC}"
    echo ""
    echo "Troubleshooting:"
    if [ $REDIS_STATUS -eq 1 ]; then
        echo "- Redis: Check docker-compose logs redis"
    fi
    if [ $GO_STATUS -eq 1 ]; then
        echo "- Go Orchestrator: Check docker-compose logs go-orchestrator"
    fi
    if [ $PYTHON_STATUS -eq 1 ]; then
        echo "- Python AI: Check docker-compose logs python-ai"
    fi
    if [ $CONTAINER_STATUS -eq 1 ]; then
        echo "- Containers: Run 'docker-compose up -d' to start services"
    fi
    exit 1
fi
