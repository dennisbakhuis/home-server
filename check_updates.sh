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

# Parse service→image mapping from docker compose config (JSON output)
declare -A SERVICE_IMAGE
while IFS='=' read -r svc img; do
    [[ -n "$svc" && -n "$img" ]] && SERVICE_IMAGE["$svc"]="$img"
done < <(docker compose config --format json 2>/dev/null | python3 -c "
import sys, json
config = json.load(sys.stdin)
for svc, details in config.get('services', {}).items():
    img = details.get('image', '')
    if img:
        print(f'{svc}={img}')
")

if [ ${#SERVICE_IMAGE[@]} -eq 0 ]; then
    echo -e "${RED}❌ Could not parse service images from docker-compose.yml${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Checking ${#SERVICE_IMAGE[@]} services in parallel...${NC}"
echo -e "${BLUE}----------------------------------------------------${NC}"

TMPDIR_RESULTS=$(mktemp -d)

# Check a single service in the background
check_service() {
    local SERVICE=$1
    local IMAGE=$2
    local OUTFILE=$3

    LOCAL_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" 2>/dev/null | cut -d'@' -f2)
    REMOTE_DIGEST=$(docker manifest inspect "$IMAGE" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    digest = (d.get('config', {}) or {}).get('digest', '')
    if not digest:
        for m in d.get('manifests', []):
            if (m.get('platform') or {}).get('architecture') == 'amd64':
                digest = m.get('digest', '')
                break
    print(digest)
except:
    pass
" 2>/dev/null)

    if [ -z "$REMOTE_DIGEST" ]; then
        echo "error|${SERVICE}|${IMAGE}|could not fetch remote digest" > "$OUTFILE"
    elif [ -z "$LOCAL_DIGEST" ]; then
        echo "update|${SERVICE}|${IMAGE}|not yet pulled locally" > "$OUTFILE"
    elif [ "$REMOTE_DIGEST" = "$LOCAL_DIGEST" ]; then
        echo "ok|${SERVICE}|${IMAGE}|" > "$OUTFILE"
    else
        echo "update|${SERVICE}|${IMAGE}|" > "$OUTFILE"
    fi
}

# Launch all checks in parallel
declare -A PIDS
for SERVICE in "${!SERVICE_IMAGE[@]}"; do
    IMAGE="${SERVICE_IMAGE[$SERVICE]}"
    OUTFILE="${TMPDIR_RESULTS}/${SERVICE}"
    check_service "$SERVICE" "$IMAGE" "$OUTFILE" &
    PIDS["$SERVICE"]=$!
done

# Show progress while waiting
TOTAL=${#PIDS[@]}
DONE=0
while [ $DONE -lt $TOTAL ]; do
    DONE=0
    for SERVICE in "${!PIDS[@]}"; do
        if ! kill -0 "${PIDS[$SERVICE]}" 2>/dev/null; then
            ((DONE++))
        fi
    done
    echo -ne "\r  ⏳ Checked ${DONE}/${TOTAL}..."
    sleep 0.3
done
wait
echo -e "\r  ✅ All checks complete.          "
echo ""

# Collect results
UPDATES_AVAILABLE=()
NO_UPDATES=()
ERRORS=()

for SERVICE in $(echo "${!SERVICE_IMAGE[@]}" | tr ' ' '\n' | sort); do
    OUTFILE="${TMPDIR_RESULTS}/${SERVICE}"
    IMAGE="${SERVICE_IMAGE[$SERVICE]}"
    if [ ! -f "$OUTFILE" ]; then
        ERRORS+=("${SERVICE} (${IMAGE}) — no result")
        continue
    fi
    IFS='|' read -r STATUS SVC IMG NOTE < "$OUTFILE"
    case "$STATUS" in
        ok)     NO_UPDATES+=("${SERVICE} (${IMAGE})") ;;
        update) UPDATES_AVAILABLE+=("${SERVICE} (${IMAGE})${NOTE:+ — $NOTE}") ;;
        error)  ERRORS+=("${SERVICE} (${IMAGE}) — ${NOTE}") ;;
    esac
done

rm -rf "$TMPDIR_RESULTS"

# Print summary
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

if [ ${#UPDATES_AVAILABLE[@]} -eq 0 ] && [ ${#ERRORS[@]} -eq 0 ]; then
    echo -e "${GREEN}🎉 All services are up to date!${NC}"
elif [ ${#UPDATES_AVAILABLE[@]} -gt 0 ]; then
    echo -e "${CYAN}💡 To apply updates, run:${NC}"
    echo -e "   ${YELLOW}./upgrade_containers.sh${NC}"
fi

echo ""
