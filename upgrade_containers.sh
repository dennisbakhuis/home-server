#!/bin/bash
##########################
# Home Server Upgrade    #
# Author: Dennis Bakhuis #
##########################
#
# This script upgrades all Docker containers to their latest versions
# Usage: ./upgrade_containers.sh

set -e  # Exit on error

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo ""
echo -e "${MAGENTA}================================================${NC}"
echo -e "${CYAN}🚀 Home Server Upgrade Script${NC}"
echo -e "${MAGENTA}================================================${NC}"
echo ""

# Check if docker compose is available
if ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Error: docker compose not found. Please install Docker Compose V2 first.${NC}"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ Error: .env file not found. Please create it from env.example${NC}"
    exit 1
fi

echo -e "${YELLOW}📥 Step 1: Pulling latest images...${NC}"
echo -e "${BLUE}--------------------------------${NC}"
docker compose pull

echo ""
echo -e "${YELLOW}🔄 Step 2: Recreating all containers...${NC}"
echo -e "${BLUE}-------------------------------------${NC}"
echo -e "${CYAN}This will force-recreate all containers, rebuild if needed, and remove orphans...${NC}"
docker compose up -d --force-recreate --build --remove-orphans

echo ""
echo -e "${YELLOW}🧹 Step 3: Cleaning up old images...${NC}"
echo -e "${BLUE}-----------------------------------${NC}"
docker image prune -f

echo ""
echo -e "${YELLOW}📊 Step 4: Checking container status...${NC}"
echo -e "${BLUE}--------------------------------------${NC}"
docker compose ps

echo ""
echo -e "${MAGENTA}================================================${NC}"
echo -e "${GREEN}✅ Upgrade completed successfully!${NC}"
echo -e "${MAGENTA}================================================${NC}"
echo ""
echo -e "${CYAN}💡 To view logs of a specific service, run:${NC}"
echo -e "   ${YELLOW}docker compose logs -f <service-name>${NC}"
echo ""
echo -e "${CYAN}💡 To view logs of all services, run:${NC}"
echo -e "   ${YELLOW}docker compose logs -f${NC}"
echo ""
