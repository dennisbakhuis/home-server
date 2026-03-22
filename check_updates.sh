#!/bin/bash
###############################
# Home Server Update Checker  #
# Author: Dennis Bakhuis      #
###############################
#
# This script checks if Docker container updates are available
# without pulling or restarting anything.
# Usage: ./check_updates.sh

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
echo -e "${CYAN}🔍 Home Server Update Checker${NC}"
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

echo -e "${YELLOW}📋 Checking services defined in docker-compose.yml...${NC}"
echo -e "${BLUE}----------------------------------------------------${NC}"

UPDATES_AVAILABLE=()
NO_UPDATES=()
ERRORS=()

# Get all service names
SERVICES=$(docker compose config --services 2>/dev/null)

for SERVICE in $SERVICES; do
    # Get the image name for this service
    IMAGE=$(docker compose config 2>/dev/null | grep -A5 "^  ${SERVICE}:" | grep "image:" | awk '{print $2}')

    if [ -z "$IMAGE" ]; then
        ERRORS+=("$SERVICE (no image found, may be build-only)")
        continue
    fi

    echo -ne "  Checking ${CYAN}${SERVICE}${NC} (${IMAGE})... "

    # Pull manifest only (no actual download) to check for updates
    REMOTE_DIGEST=$(docker manifest inspect "$IMAGE" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('config',{}).get('digest','') or next((m.get('digest','') for m in d.get('manifests',[]) if m.get('platform',{}).get('architecture')=='amd64'),''  ))" 2>/dev/null)

    LOCAL_DIGEST=$(docker inspect "$IMAGE" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d'@' -f2)

    if [ -z "$REMOTE_DIGEST" ]; then
        echo -e "${YELLOW}⚠️  could not fetch remote digest${NC}"
        ERRORS+=("$SERVICE ($IMAGE)")
    elif [ -z "$LOCAL_DIGEST" ]; then
        echo -e "${YELLOW}⚠️  not pulled locally yet${NC}"
        UPDATES_AVAILABLE+=("$SERVICE ($IMAGE) — not yet pulled")
    elif [ "$REMOTE_DIGEST" = "$LOCAL_DIGEST" ]; then
        echo -e "${GREEN}✅ up to date${NC}"
        NO_UPDATES+=("$SERVICE")
    else
        echo -e "${RED}🔄 update available${NC}"
        UPDATES_AVAILABLE+=("$SERVICE ($IMAGE)")
    fi
done

echo ""
echo -e "${MAGENTA}================================================${NC}"
echo -e "${CYAN}📊 Summary${NC}"
echo -e "${MAGENTA}================================================${NC}"
echo ""

if [ ${#UPDATES_AVAILABLE[@]} -gt 0 ]; then
    echo -e "${RED}🔄 Updates available (${#UPDATES_AVAILABLE[@]}):${NC}"
    for SVC in "${UPDATES_AVAILABLE[@]}"; do
        echo -e "   • ${YELLOW}${SVC}${NC}"
    done
    echo ""
fi

if [ ${#NO_UPDATES[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Up to date (${#NO_UPDATES[@]}):${NC}"
    for SVC in "${NO_UPDATES[@]}"; do
        echo -e "   • ${SVC}"
    done
    echo ""
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Could not check (${#ERRORS[@]}):${NC}"
    for SVC in "${ERRORS[@]}"; do
        echo -e "   • ${SVC}"
    done
    echo ""
fi

if [ ${#UPDATES_AVAILABLE[@]} -eq 0 ]; then
    echo -e "${GREEN}🎉 All services are up to date!${NC}"
else
    echo -e "${CYAN}💡 To apply updates, run:${NC}"
    echo -e "   ${YELLOW}./upgrade_containers.sh${NC}"
fi

echo ""
