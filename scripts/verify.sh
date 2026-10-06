#!/usr/bin/env bash
# Checks that every lab service is running and answering correctly.
# Run as root on the server after setup.sh.
set -uo pipefail

SERVER=192.168.100.33
failures=0

check() {
  local name=$1
  shift
  if "$@" &>/dev/null; then
    printf '  [OK]   %s\n' "$name"
  else
    printf '  [FAIL] %s\n' "$name"
    failures=$((failures + 1))
  fi
}

resolves_to() {
  [[ "$(dig @"$SERVER" +short "$1" | tail -n1)" == "$2" ]]
}

echo "Services"
for service in isc-dhcp-server named apache2 vsftpd postfix dovecot; do
  check "$service is running" systemctl is-active --quiet "$service"
done

echo "DNS"
check "zone file is valid" named-checkzone tercera.com /etc/bind/db.tercera.com
check "www.tercera.com -> $SERVER" resolves_to www.tercera.com "$SERVER"
check "web.tercera.com (CNAME) -> $SERVER" resolves_to web.tercera.com "$SERVER"
check "MX record points to mail.tercera.com" \
  bash -c "dig @$SERVER +short MX tercera.com | grep -q 'mail.tercera.com.'"

echo "Web"
check "www.tercera.com serves the lab page" \
  bash -c "curl -s -H 'Host: www.tercera.com' http://$SERVER/ | grep -q 'TERCER TRIMESTRE'"

echo "FTP"
check "port 21 is listening" bash -c "ss -ltn | grep -q ':21 '"
check "server requires TLS (AUTH TLS offered)" \
  bash -c "printf 'FEAT\r\nQUIT\r\n' | timeout 5 nc $SERVER 21 | grep -q 'AUTH TLS'"

echo "Mail"
marker="verify-$(date +%s)"
echo "Test message $marker" | sendmail david@tercera.com
sleep 3
check "local delivery to david@tercera.com" \
  bash -c "grep -rqs '$marker' /home/david/Maildir/new"
check "IMAP is listening" bash -c "ss -ltn | grep -q ':143 '"

echo
if (( failures == 0 )); then
  echo "All checks passed."
else
  echo "$failures check(s) failed."
  exit 1
fi
