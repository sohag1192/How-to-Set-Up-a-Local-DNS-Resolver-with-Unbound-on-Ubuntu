#!/bin/bash

# Author: Md. Sohag Rana
# Repo: https://github.com/sohag1192/How-to-Set-Up-a-Local-DNS-Resolver-with-Unbound-on-Ubuntu
# Description: Automates Unbound DNS Resolver setup with DNS-over-TLS, logging, and local zone

set -e

# === CONFIGURATION ===
IP="100.100.100.37"
LOCAL_ZONE="sohag.lan"
ZONE_HOSTNAME="ns.sohag.lan"
UNBOUND_CONF="/etc/unbound/unbound.conf"
RSYSLOG_CONF="/etc/rsyslog.d/unbound.conf"
LOGROTATE_CONF="/etc/logrotate.d/unbound"

# === INSTALL UNBOUND ===
echo "[+] Installing Unbound DNS Resolver"
sudo apt update
sudo apt install -y unbound

# === VERIFY SERVICE ===
echo "[+] Verifying Unbound service"
sudo systemctl is-enabled unbound
sudo systemctl status unbound

# === CONFIGURE UNBOUND ===
echo "[+] Writing Unbound configuration"
sudo tee "$UNBOUND_CONF" > /dev/null <<EOF
server:
  use-syslog: yes
  username: "unbound"
  directory: "/etc/unbound"
  tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt
  do-ip6: no
  interface: $IP
  port: 53
  prefetch: yes
  root-hints: /usr/share/dns/root.hints
  harden-dnssec-stripped: yes
  cache-max-ttl: 14400
  cache-min-ttl: 1200
  aggressive-nsec: yes
  hide-identity: yes
  hide-version: yes
  use-caps-for-id: yes

  access-control: 10.0.0.0/8 allow
  access-control: 192.168.0.0/16 allow
  access-control: 172.16.0.0/12 allow

  local-zone: "$LOCAL_ZONE." static
  local-data: "$ZONE_HOSTNAME. IN A $IP"
  local-data-ptr: "$IP $ZONE_HOSTNAME"

  num-threads: 4
  msg-cache-slabs: 8
  rrset-cache-slabs: 8
  infra-cache-slabs: 8
  key-cache-slabs: 8
  rrset-cache-size: 256m
  msg-cache-size: 128m
  so-rcvbuf: 8m

forward-zone:
  name: "."
  forward-ssl-upstream: yes
  forward-addr: 9.9.9.9@853#dns.quad9.net
  forward-addr: 149.112.112.112@853#dns.quad9.net
  forward-addr: 8.8.8.8@853
  forward-addr: 4.4.4.4@853
EOF

# === RESTART UNBOUND ===
echo "[+] Restarting Unbound"
sudo systemctl restart unbound

# === SETUP LOGGING ===
echo "[+] Configuring Rsyslog for Unbound"
sudo tee "$RSYSLOG_CONF" > /dev/null <<EOF
if \$programname == 'unbound' then /var/log/unbound.log
& stop
EOF

sudo systemctl restart rsyslog

# === SETUP LOGROTATE ===
echo "[+] Configuring log rotation"
sudo tee "$LOGROTATE_CONF" > /dev/null <<EOF
/var/log/unbound.log {
  daily
  rotate 7
  missingok
  create 0640 root adm
  postrotate
    /usr/lib/rsyslog/rsyslog-rotate
  endscript
}
EOF

sudo systemctl restart logrotate

echo "✅ Unbound DNS Resolver setup complete with DNS-over-TLS and logging"
