#!/bin/bash

#Переименование виртуалки
hostnamectl set-hostname br-srv.au-team.irpo; 

#Настройка интерфейсов и времени
cat <<EOF > /etc/net/ifaces/ens18/options
TYPE=eth
DISABLED=no
NM_CONTROLLED=no
BOOTPROTO=static
IPV4_CONFIG=yes
EOF

touch /etc/net/ifaces/ens18/ipv4address
cat <<EOF > /etc/net/ifaces/ens18/ipv4address
192.168.13.14/28
EOF

touch /etc/net/ifaces/ens18/ipv4route
cat <<EOF > /etc/net/ifaces/ens18/ipv4route
default via 192.168.13.1
EOF

cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 77.88.8.8
EOF

timedatectl set-timezone Europe/Samara
systemctl restart network

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

#Создание NTP
apt-get install chrony -y 
sed -i '3i#pool pool.ntp.org iburst' /etc/chrony.conf
systemctl enable --now chronyd

cat <<EOF >> /etc/resolv.conf 
nameserver 8.8.8.8
EOF

#Создание Samba DC
apt-get update && apt-get install -y task-samba-dc bind 
control bind-chroot disabled
grep -q KRB5RCACHETYPE /etc/sysconfig/bind || echo 'KRB5RCACHETYPE="none"' >> /etc/sysconfig/bind
systemctl stop bind
rm -f /etc/samba/smb.conf
rm -rf /var/lib/samba
rm -rf /var/cache/samba
mkdir -p /var/lib/samba/sysvol
samba-tool domain provision --realm=au-team.irpo --domain=au-team --adminpass='P@ssw0rd' --dns-backend=SAMBA_INTERNAL --server-role=dc --use-rfc2307
systemctl restart samba
systemctl enable --now samba
samba-tool domain info 127.0.0.1
samba-tool computer list
samba-tool group add hq
for i in {1..5}; do
samba-tool user add user$i-hq P@ssw0rd;
samba-tool user setexpiry user$i-hq --noexpiry;
samba-tool group addmembers "hq" user$i-hq;
done
apt-get install -y admx-*
amdx-msi-setup

#Настройка Ansible
apt-get install -y ansible sshpass
sed -i 's/^#inventory      = \/etc\/ansible\/hosts/inventory      = \/etc\/ansible\/hosts/' /etc/ansible/ansible.cfg 
echo "host_key_checking = False" | tee -a /etc/ansible/ansible.cfg
cat > /etc/ansible/hosts <<EOF
HQ-RTR ansible_host=192.168.14.1 ansible_user=net_admin ansible_password=P@$$word ansible_connection=network_cli ansible_network_os=ios
BR-RTR ansible_host=192.168.13.1 ansible_user=net_admin ansible_password=P@$$word ansible_connection=network_cli ansible_network_os=ios
HQ-SRV ansible_host=192.168.14.30 ansible_user=sshuser ansible_password=P@ssw0rd ansible_ssh_port=2024
HQ-CLI ansilbe_host=192.168.14.65 ansible_user=sshuser ansible_password=P@ssw0rd ansible_ssh_port=2024

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
ansible -m ping all



grep -E "Port|MaxAuthTries|PasswordAuthentication|PubkeyAuthentication" "$CONFIG_FILE"
