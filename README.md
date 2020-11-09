# Server Installation instructions
This a repository with my installation of my domotica servers. In a fresh install of Ubuntu 20.04 Server
I install docker and run the following services:
- Traefik (reversed proxy)
- Pihole (DNS server to block adds)
- Deconz (Service for my Zigbee network)
- Mosquitto (MQTT broker)
- Home assistant (My home automation server of choice)
- Visual Studio Code Server (easy editing of configs)
- Node-Red (automation programming / will be removed soon)
- AppDaemon (automation programming <- this is amazing)
- todomini (Self-hosted todo list app / mainly for groceries)
- hass-configurator (simple home assistant configuration tool)
- Authelia (self-hosted authenication server: for selfhosted todo)

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
mkdir -p ~/docker/deconz
mkdir -p ~/docker/pihole/pihole
mkdir -p ~/docker/vscode/storage
mkdir -p ~/docker/pihole/dns-masq.d/
mkdir -p ~/docker/traefik2/acme
mkdir -p ~/docker/todomini/dennis
mkdir -p ~/docker/todomini/kim
touch ~/docker/traefik2/acme/acme.json

```
Copy example .env file and change the passwords
```bash
cd docker
cp env.example .env
vim .env
```

## Create docker network / pull images / and start the servers
docker network create --gateway 192.168.90.1 --subnet 192.168.90.0/24 t2_proxy
docker-compose pull
docker-compose up -d


## To update the containers (can be breaking changes; especially with HA)
docker-compose up --force-recreate --build -d
docker image prune -f

## Authelia
Authelia has secrets stored in /secrets that are required. Examples are stored in /examples/
