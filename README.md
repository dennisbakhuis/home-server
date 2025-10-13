# Server Installation instructions
This a repository with my installation of my domotica servers. In a fresh install of Ubuntu 20.04 Server
I install docker and run the following services:
- **Traefik** - Reverse proxy with automatic SSL certificates via Cloudflare DNS challenge
- **Mosquitto** - MQTT broker for IoT device communication
- **Home Assistant** - Home automation platform for managing smart devices
- **Node-RED** - Flow-based automation and integration platform
- **Grott** - Growatt solar inverter monitoring and data collection
- **Heimdall** - Application dashboard for organizing server services
- **Voorvoet Import Tool** - Custom e-Boekhouden accounting import application
- **Teslamate** - Tesla vehicle data logging and tracking
- **Tesla Grafana** - Grafana dashboard for Tesla vehicle metrics visualization

This is a description meant to help me, but it might be useful for you too. Feel free to contact me on
[LinkedIn](https://linkedin.com/in/dennisbakhuis).

## Install fresh Ubuntu 20.04 LTS:
- Add Openssh
- Do not add docker (it is a Snap app which is annoying)

## Setup basics for easier editing
git clone https://github.com/dennisbakhuis/dotfiles.git
cd dotfiles
./install_linux.sh

Open vim and do :PlugInstall
Logout and relogin.

## Turn off local 53 port binding
When editing I use vim. Feel free to use anything other (i.e. nano).

I followed this [guide](https://www.linuxuprising.com/2020/07/ubuntu-how-to-free-up-port-53-used-by.html).

1) edit /etc/systemd/resolv.conf and add/change the following:
```bash
DNS=1.1.1.1
DNSStubListener=no
```
2) create a symlink to resolv.conf:
```bash
sudo ln -sf /run/systemd/resolve/resolv.conf
```

## Update server and install docker
```bash
sudo apt update
sudo apt upgrade
sudo apt install docker docker-compose acl
```
We also need to add the user to the docker group to use docker without sudo:
```bash
sudo gpasswd -a $USER docker
```

## Reboot
We need a reboot to have port 53 freed. You could however also just restart the network, but a reboot is
relatively fast.
```bash
sudo reboot
```

## Prepare home server directory
Clone the server setup:
```bash
git clone https://github.com/dennisbakhuis/home-server.git
mv ./home-server ./docker
sudo setfacl -Rdm g:docker:rwx ~/docker
sudo chmod -R 775 ~/docker
mkdir -p ~/docker/traefik/acme
mkdir -p ~/docker/traefik/logs
mkdir -p ~/docker/traefik/rules
mkdir -p ~/docker/mosquitto
mkdir -p ~/docker/homeassistant/config
mkdir -p ~/docker/node_red
mkdir -p ~/docker/heimdall
mkdir -p ~/docker/shared
touch ~/docker/traefik/acme/acme.json
chmod 600 ~/docker/traefik/acme/acme.json

```
Copy example .env file and change the passwords
```bash
cd docker
cp env.example .env
vim .env
```

## Create docker network / pull images / and start the servers
```bash
docker network create --gateway 192.168.90.1 --subnet 192.168.90.0/24 t2_proxy
docker compose pull
docker compose up -d
```

## To update all containers
Use the automated upgrade script (recommended):
```bash
./upgrade_containers.sh
```

Or manually update all containers:
```bash
docker compose pull
docker compose up -d --force-recreate --build --remove-orphans
docker image prune -f
```

## To update a specific service
Update a single service without affecting others (replace `traefik` with any service name):
```bash
docker compose up -d traefik --force-recreate --pull always
```
