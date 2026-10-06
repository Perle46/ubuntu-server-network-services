;
; Zone file for tercera.com
;
$TTL    604800
@       IN      SOA     ns.tercera.com. admin.tercera.com. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns.tercera.com.
@       IN      MX  10  mail.tercera.com.
@       IN      A       192.168.100.33
ns      IN      A       192.168.100.33
www     IN      A       192.168.100.33
ftp     IN      A       192.168.100.33
mail    IN      A       192.168.100.33
web     IN      CNAME   www
trans   IN      CNAME   ftp
