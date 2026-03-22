#!/bin/bash
###############################
# Home Server Update Checker  #
# Author: Dennis Bakhuis      #
###############################
#
# Checks each docker-compose service for available updates by comparing
# the local image version label against the remote registry — no pull needed.
# Usage: ./check_updates.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo ""
echo -e "${MAGENTA}================================================${NC}"
echo -e "${CYAN}🔍 Home Server Update Checker${NC}"
echo -e "${MAGENTA}================================================${NC}"
echo ""

if ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Error: docker compose not found.${NC}"
    exit 1
fi

if [ ! -f .env ]; then
    echo -e "${RED}❌ Error: .env file not found. Please create it from env.example${NC}"
    exit 1
fi

# Extract service→image mapping and pipe into the Python checker
docker compose config --format json 2>/dev/null | python3 -c "
import sys, json
config = json.load(sys.stdin)
for svc, details in config.get('services', {}).items():
    img = details.get('image', '')
    if img:
        print(f'{svc}={img}')
" | python3 << 'PYEOF'
import json, sys, subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
import urllib.request, urllib.error

# ── Registry helpers ──────────────────────────────────────────────────────────

def parse_image(image):
    """Return (registry_host, repo, tag) from an image string."""
    tag = 'latest'
    if ':' in image.split('/')[-1]:
        image, tag = image.rsplit(':', 1)
    parts = image.split('/')
    if len(parts) == 1:
        return 'registry-1.docker.io', f'library/{parts[0]}', tag
    if '.' in parts[0] or parts[0] == 'localhost':
        host = parts[0]
        repo = '/'.join(parts[1:])
        # lscr.io mirrors ghcr.io
        if host == 'lscr.io':
            host = 'ghcr.io'
        return host, repo, tag
    # user/image on Docker Hub
    return 'registry-1.docker.io', image, tag

def get_token(host, repo):
    """Fetch an anonymous pull token for the given registry."""
    if host == 'registry-1.docker.io':
        url = f'https://auth.docker.io/token?service=registry.docker.io&scope=repository:{repo}:pull'
    elif host == 'ghcr.io':
        url = f'https://ghcr.io/token?scope=repository:{repo}:pull&service=ghcr.io'
    else:
        url = f'https://{host}/token?scope=repository:{repo}:pull&service={host}'
    try:
        with urllib.request.urlopen(url, timeout=10) as r:
            d = json.loads(r.read())
            return d.get('token') or d.get('access_token', '')
    except Exception:
        return ''

def fetch(url, token=None, accept=None):
    req = urllib.request.Request(url)
    if token:
        req.add_header('Authorization', f'Bearer {token}')
    if accept:
        req.add_header('Accept', accept)
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())

def get_remote_version(image):
    """Return (version_str, config_digest) from the registry without pulling."""
    host, repo, tag = parse_image(image)
    token = get_token(host, repo)
    base = f'https://{host}/v2/{repo}'

    MANIFEST_ACCEPT = ','.join([
        'application/vnd.oci.image.index.v1+json',
        'application/vnd.docker.distribution.manifest.list.v2+json',
        'application/vnd.oci.image.manifest.v1+json',
        'application/vnd.docker.distribution.manifest.v2+json',
    ])

    manifest = fetch(f'{base}/manifests/{tag}', token=token, accept=MANIFEST_ACCEPT)

    # If manifest list, find linux/amd64 entry
    if 'manifests' in manifest:
        target = next(
            (m for m in manifest['manifests']
             if (m.get('platform') or {}).get('architecture') == 'amd64'
             and (m.get('platform') or {}).get('os') == 'linux'),
            manifest['manifests'][0]
        )
        manifest = fetch(f'{base}/manifests/{target["digest"]}', token=token,
                         accept='application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json')

    config_digest = manifest.get('config', {}).get('digest', '')
    if not config_digest:
        return None, None

    config = fetch(f'{base}/blobs/{config_digest}', token=token)
    labels = (config.get('config') or config.get('Config') or {}).get('Labels') or {}
    version = (
        labels.get('org.opencontainers.image.version')
        or labels.get('build_version')          # linuxserver images
        or (config.get('created') or '')[:10]   # fallback: build date
    )
    return version or None, config_digest

def get_local_info(image):
    """Return (version_str, config_digest) from the local Docker image store."""
    r = subprocess.run(['docker', 'inspect', image, '--format', '{{json .}}'],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return None, None
    try:
        info = json.loads(r.stdout)
        if isinstance(info, list):
            info = info[0]
        labels = (info.get('Config') or {}).get('Labels') or {}
        version = (
            labels.get('org.opencontainers.image.version')
            or labels.get('build_version')
            or (info.get('Created') or '')[:10]
        )
        digests = info.get('RepoDigests', [])
        digest = digests[0].split('@')[1] if digests else ''
        return version or None, digest
    except Exception:
        return None, None

# ── Per-service check ─────────────────────────────────────────────────────────

def check_service(service, image):
    local_ver, local_digest = get_local_info(image)
    try:
        remote_ver, remote_digest = get_remote_version(image)
    except Exception as e:
        return dict(status='error', service=service, image=image,
                    local=local_ver, remote=None, error=str(e))

    if local_digest and remote_digest:
        up_to_date = local_digest == remote_digest
    else:
        # Fall back to version string compare if digests unavailable
        up_to_date = (local_ver == remote_ver) if (local_ver and remote_ver) else None

    return dict(
        status='ok' if up_to_date else ('update' if up_to_date is False else 'unknown'),
        service=service, image=image,
        local=local_ver or '?', remote=remote_ver or '?', error=None
    )

# ── Main ──────────────────────────────────────────────────────────────────────

services = {}
for line in sys.stdin:
    line = line.strip()
    if '=' in line:
        svc, img = line.split('=', 1)
        services[svc] = img

results = []
with ThreadPoolExecutor(max_workers=10) as ex:
    futures = {ex.submit(check_service, s, i): s for s, i in services.items()}
    done = 0
    total = len(futures)
    for fut in as_completed(futures):
        done += 1
        print(f'\r  \033[1;33m⏳ Checked {done}/{total}...\033[0m', end='', flush=True, file=sys.stderr)
        results.append(fut.result())

print(f'\r  \033[0;32m✅ All checks complete.          \033[0m', file=sys.stderr)

results.sort(key=lambda x: x['service'])

updates, ok, errors = [], [], []
for r in results:
    if r['status'] == 'update':
        updates.append(r)
    elif r['status'] == 'ok':
        ok.append(r)
    else:
        errors.append(r)

print()
print('\033[0;35m================================================\033[0m')
print('\033[0;36m📊 Summary\033[0m')
print('\033[0;35m================================================\033[0m')
print()

if updates:
    print(f'\033[0;31m🔄 Updates available ({len(updates)}):\033[0m')
    for r in updates:
        print(f'   \033[1;33m• {r["service"]}\033[0m  ({r["image"]})')
        print(f'     Current : {r["local"]}')
        print(f'     Latest  : \033[0;32m{r["remote"]}\033[0m')
    print()

if ok:
    print(f'\033[0;32m✅ Up to date ({len(ok)}):\033[0m')
    for r in ok:
        print(f'   • {r["service"]}  \033[0;90m({r["local"]})\033[0m')
    print()

if errors:
    print(f'\033[1;33m⚠️  Could not check ({len(errors)}):\033[0m')
    for r in errors:
        local_info = f', local: {r["local"]}' if r.get('local') else ''
        print(f'   • {r["service"]}  ({r["image"]}{local_info})')
        if r.get('error'):
            print(f'     \033[0;90m{r["error"]}\033[0m')
    print()

if updates:
    print('\033[0;36m💡 To apply updates, run:\033[0m')
    print('   \033[1;33m./upgrade_containers.sh\033[0m')
elif not errors:
    print('\033[0;32m🎉 All services are up to date!\033[0m')
print()
PYEOF
