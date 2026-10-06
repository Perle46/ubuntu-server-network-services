#!/usr/bin/env bash
# Configures DHCP, DNS, web, FTP and mail for the tercera.com lab
# on a fresh Ubuntu Server 24.04 LTS. Run as root from the repository.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$REPO_DIR/config"
USERS=(david angela)

step() { printf '\n==> %s\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

step "Installing packages"
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< "postfix postfix/main_mailer_type select Internet Site"
debconf-set-selections <<< "postfix postfix/mailname string tercera.com"
apt-get update -q
apt-get install -y -q isc-dhcp-server bind9 bind9-utils bind9-dnsutils apache2 vsftpd \
  postfix dovecot-imapd ssl-cert ufw

step "Network: static address on enp0s8"
install -m 600 "$CONFIG/netplan/60-lan.yaml" /etc/netplan/60-lan.yaml
netplan apply

step "DHCP"
install -m 644 "$CONFIG/dhcp/dhcpd.conf" /etc/dhcp/dhcpd.conf
install -m 644 "$CONFIG/dhcp/isc-dhcp-server" /etc/default/isc-dhcp-server
dhcpd -t -cf /etc/dhcp/dhcpd.conf
systemctl restart isc-dhcp-server

step "DNS"
install -m 644 -g bind "$CONFIG/bind/named.conf.local" /etc/bind/named.conf.local
install -m 644 -g bind "$CONFIG/bind/db.tercera.com" /etc/bind/db.tercera.com
named-checkconf
named-checkzone tercera.com /etc/bind/db.tercera.com
systemctl restart named

step "Web"
install -d -m 755 /var/www/tercera.com
install -m 644 "$CONFIG/apache/index.html" /var/www/tercera.com/index.html
install -m 644 "$CONFIG/apache/tercera.com.conf" /etc/apache2/sites-available/tercera.com.conf
a2dissite -q 000-default
a2ensite -q tercera.com
apache2ctl configtest
systemctl reload apache2

step "Users"
for user in "${USERS[@]}"; do
  if ! id "$user" &>/dev/null; then
    useradd -m -s /bin/bash "$user"
    echo "Choose a password for $user:"
    passwd "$user"
  fi
  # FTP jail: root-owned and read-only, with a writable folder inside
  install -d -o root -g root -m 755 "/home/$user/ftp"
  install -d -o "$user" -g "$user" -m 755 "/home/$user/ftp/files"
done

step "FTP"
install -m 644 "$CONFIG/vsftpd/vsftpd.conf" /etc/vsftpd.conf
printf '%s\n' "${USERS[@]}" > /etc/vsftpd.userlist
systemctl restart vsftpd

step "Mail"
grep -Ev '^\s*(#|$)' "$CONFIG/postfix/main.cf.settings" | while IFS= read -r setting; do
  postconf -e "$setting"
done
install -m 644 "$CONFIG/dovecot/local.conf" /etc/dovecot/local.conf
postfix check
doveconf -n > /dev/null
systemctl restart postfix dovecot

step "Firewall"
ufw allow OpenSSH
ufw allow 53                 # DNS (TCP and UDP)
ufw allow 67/udp             # DHCP
ufw allow 80/tcp             # HTTP
ufw allow 21/tcp             # FTP control
ufw allow 40000:40100/tcp    # FTP passive data
ufw allow 25/tcp             # SMTP
ufw allow 143/tcp            # IMAP (STARTTLS)
ufw --force enable

step "Done. Run scripts/verify.sh to check every service."
