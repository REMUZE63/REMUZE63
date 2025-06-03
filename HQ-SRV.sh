#!/bin/bash

hostnamectl set-hostname hq-srv.au-team.irpo
cat <<EOF > /etc/net/ifaces/ens18/options
TYPE=eth
DISABLED=no
NM_CONTROLLED=no
BOOTPROTO=static
IPV4_CONFIG=yes
EOF

touch /etc/net/ifaces/ens18/ipv4address
cat <<EOF > /etc/net/ifaces/ens18/ipv4address
192.168.14.30/27
EOF

touch /etc/net/ifaces/ens18/ipv4route
cat <<EOF > /etc/net/ifaces/ens18/ipv4route
default via 192.168.14.1
EOF

cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
EOF
systemctl restart network

#Создание пользователя sshuser и настройка sshd конфига
useradd sshuser -u 1015
echo "sshuser:P@ssw0rd" | chpasswd
usermod -aG wheel sshuser

touch /etc/sudoers
cat <<EOF /etc/sudoers
sshuser ALL=(ALL) NOPASSWD:ALL
EOF

CONFIG_FILE="/etc/openssh/sshd_config"


echo "AllowUsers sshuser" | tee -a /etc/openssh/sshd_config
awk -i inplace '/^#?Port[[:space:]]+22$/ {sub(/^#/,""); sub(/22/,"2024"); print; next} {print}' "$CONFIG_FILE"
awk -i inplace '/^#?MaxAuthTries[[:space:]]+6$/ {sub(/^#/,""); sub(/6/,"2"); print; next} {print}' "$CONFIG_FILE"
awk -i inplace '/^#?PasswordAuthentication[[:space:]]+(yes|no)$/ {sub(/^#/,""); sub(/no/,"yes"); print; next} {print}' "$CONFIG_FILE"
awk -i inplace '/^#?PubkeyAuthentication[[:space:]]+(yes|no)$/ {sub(/^#/,""); sub(/no/,"yes"); print; next} {print}' "$CONFIG_FILE"

touch /etc/openssh/banner 
cat <<EOF > /etc/openssh/banner
Authorized access only  


EOF  

systemctl restart sshd  
apt-get update && apt-get install -y dnsmasq
cat > /etc/dnsmasq.conf <<EOF
no-resolv
no-poll
no-hosts
listen-address=192.168.14.30

server=77.88.8.8
server=8.8.8.8

cache-size=1000
all-servers
no-negcache

host-record=hq-rtr.au-team.irpo,192.168.14.1
host-record=hq-srv.au-team.irpo,192.168.14.30
host-record=hq-cli.au-team.irpo,192.168.14.66

address=/br-rtr.au-team.irpo/192.168.13.1
address=/br-srv.au-team.irpo/192.168.13.30

cname=moodle.au-team.irpo,hq-rtr.au-team.irpo
cname=wiki.au-team.irpo,hq-rtr.au-team.irpo
EOF
systemctl restart dnsmasq

grep -E "Port|MaxAuthTries|PasswordAuthentication|PubkeyAuthentication" "$CONFIG_FILE"
cat /etc/dnsmasq.conf
timedatectl

