#!/usr/bin/env bash

clear
cd ~

ipaddr=""
default=$(wget -qO- ipv4.icanhazip.com);
read -p "IP address [$default]: " ipaddr
ipaddr=${ipaddr:-$default}

echo

echo -n "Change localtime zone..."
ln -fs /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime
echo "[ DONE ]"

echo -n "Disable network IPV6..."
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local
echo "[ DONE ]"

echo -n "Enable network IPV4 forward..."
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf
echo "[ DONE ]"

echo -n "Add DNS Server..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
sed -i '$ i\echo "nameserver 8.8.8.8" > /etc/resolv.conf' /etc/rc.local
sed -i '$ i\echo "nameserver 8.8.4.4" >> /etc/resolv.conf' /etc/rc.local
echo "[ DONE ]"

echo

echo -n "Update apt and upgrade installed packages... "
apt-get -qq update > /dev/null 2>&1
apt-get -qqy upgrade > /dev/null 2>&1
echo "[ DONE ]"

echo -n "Install required and needed packages..."
apt-get -qqy install build-essential > /dev/null 2>&1
apt-get -qqy install screen zip grepcidr > /dev/null 2>&1
echo "[ DONE ]"

echo
sleep 3
cd

# openssh
echo -n "Configure openssh conf... "
sed -i 's/#Port 22/Port 22/g' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 2020' /etc/ssh/sshd_config
echo "DONE"
/etc/init.d/ssh restart

echo
sleep 3
cd

# dropbear
echo -n "Installing dropbear package... "
apt-get -qqy install dropbear > /dev/null 2>&1
echo "[ DONE ]"

echo -n "Configure dropbear conf... "
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=4343/g' /etc/default/dropbear
echo "/bin/false" >> /etc/shells
echo "DONE"
/etc/init.d/dropbear restart

echo
sleep 3
cd

# squid3
echo -n "Installing squid package... "
apt-get -y install squid3 > /dev/null 2>&1
echo "[ DONE ]"

echo -n "Configure squid package... "
cat > /etc/squid/squid.conf <<-EOF
# NETWORK OPTIONS.
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1

# local Networks.
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
acl VPS dst $ipaddr/32

# squid Port
http_port 3128

# Minimum configuration.
http_access allow VPS
http_access allow manager localhost
http_access deny manager
http_access allow localhost
http_access allow all

# Add refresh_pattern.
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname proxy.vps-knowledge
EOF

echo "[ DONE ]"
/etc/init.d/squid restart

echo
sleep 3
cd

# openvpn
echo -n "Installing openvpn package... "
apt-get -qqy install openvpn > /dev/null 2>&1
apt-get -qqy install openssl > /dev/null 2>&1
apt-get -qqy install easy-rsa > /dev/null 2>&1
echo -e "[${green}DONE${noclr}]"

echo "Configure openvpn package... "
openssl dhparam -out /etc/openvpn/dh2048.pem 2048

cp -r /usr/share/easy-rsa/ /etc/openvpn

sed -i 's|export KEY_COUNTRY="US"|export KEY_COUNTRY="MY"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_PROVINCE="CA"|export KEY_PROVINCE="Sabah"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_CITY="SanFrancisco"|export KEY_CITY="Tawau"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_ORG="Fort-Funston"|export KEY_ORG="VPS-Knowledge"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_EMAIL="me@myhost.mydomain"|export KEY_EMAIL="vps.doctype@gmail.com"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_OU="MyOrganizationalUnit"|export KEY_OU="Doctype"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_NAME="EasyRSA"|export KEY_NAME="KnowledgeRSA"|' /etc/openvpn/easy-rsa/vars

cd /etc/openvpn/easy-rsa
ln -s openssl-1.0.0.cnf openssl.cnf
source ./vars
./clean-all
./build-ca
./build-key-server --batch server
./build-key --batch client

cd

cp /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn
cp /etc/openvpn/easy-rsa/keys/ca.key /etc/openvpn
cp /etc/openvpn/easy-rsa/keys/dh2048.pem /etc/openvpn
cp /etc/openvpn/easy-rsa/keys/server.crt /etc/openvpn
cp /etc/openvpn/easy-rsa/keys/server.key /etc/openvpn
cp /etc/openvpn/easy-rsa/keys/client.crt /etc/openvpn
cp /etc/openvpn/easy-rsa/keys/client.key /etc/openvpn


cat > /etc/openvpn/server.conf <<-EOF
port 1194
proto tcp
dev tun

ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh2048.pem

server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
user nobody
group nogroup
persist-key
persist-tun
auth SHA256
cipher AES-128-CBC
tls-server
tls-version-min 1.2
tls-cipher TLS-DHE-RSA-WITH-AES-128-GCM-SHA256
status vpn-status.log
log /var/log/openvpn.log
comp-lzo
verb 3
mute 20
EOF

systemctl start openvpn@server

cat > /etc/openvpn/client.ovpn <<-EOF
client
dev tun
proto tcp-client
remote $ipaddr 1194
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
auth SHA256
auth-nocache
ns-cert-type server
cipher AES-128-CBC
tls-client
tls-version-min 1.2
tls-cipher TLS-DHE-RSA-WITH-AES-128-GCM-SHA256

;http-proxy-retry
;http-proxy [squid] [port]
;http-proxy-option CUSTOM-HEADER Host [host]
;http-proxy-option CUSTOM-HEADER X-Online-Host [host]

mute-replay-warnings
auth-user-pass
comp-lzo
verb 3
mute 20
EOF

echo '' >> /etc/openvpn/client.ovpn
echo '<ca>' >> /etc/openvpn/client.ovpn
cat /etc/openvpn/easy-rsa/keys/ca.crt >> /etc/openvpn/client.ovpn
echo '</ca>' >> /etc/openvpn/client.ovpn
echo "DONE"
/etc/init.d/openvpn restart

echo
sleep 3
cd

# install badvpn
echo -n "Installing badvpn package... "
wget -q -O /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/prter/badvpn-udpgw"
chmod +x /usr/bin/badvpn-udpgw
sed -i '$ i\screen -AmdS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300' /etc/rc.local
screen -AmdS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300
echo -e "[ DONE ]"

# fail2ban
echo -n "Installing fail2ban package... "
apt-get -qqy install fail2ban > /dev/null 2>&1
echo "DONE"
service fail2ban restart

echo
sleep 3
cd

# ddos deflate
apt-get -y install dnsutils dsniff
wget https://github.com/jgmdev/ddos-deflate/archive/master.zip
unzip master.zip
cd ddos-deflate-master
./install.sh
rm -rf /root/master.zip

echo
sleep 3
cd

echo -n "Installing ufw package... "
apt-get -qqy install ufw > /dev/null 2>&1
echo "[ DONE ]"

echo -n "Configure ufw package... "
ufw allow 80
ufw allow 443
ufw allow 22
ufw allow 2020
ufw allow 4343
ufw allow 1194/tcp
ufw allow 3128
ufw allow 7300
ufw allow 10000

sed -i 's|DEFAULT_INPUT_POLICY="DROP"|DEFAULT_INPUT_POLICY="ACCEPT"|' /etc/default/ufw
sed -i 's|DEFAULT_FORWARD_POLICY="DROP"|DEFAULT_FORWARD_POLICY="ACCEPT"|' /etc/default/ufw

cat > /etc/ufw/before.rules << EOF
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT
EOF

echo "[ DONE ]"
ufw enable
/etc/init.d/ufw restart

echo
sleep 3

echo "You need to reboot for change to take action."
