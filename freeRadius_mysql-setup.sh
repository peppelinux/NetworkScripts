# Configure freeRadius
# https://extremeshok.com/5486/debian-7-freeradius-server-mysql-authentication/
# http://tweakpalace.com/eap-tls-freeradius2-openwrt/
# http://deployingradius.com/documents/protocols/compatibility.html
# http://deployingradius.com/scripts/eapol_test/
# eapol_test: https://ttboa.wordpress.com/2014/09/26/freeradius-on-debian-7/
# http://networkradius.com/doc/FreeRADIUS-Implementation-Ch6.pdf


set -x

#aptitude install slapd ldap-utils ldap-account-manager freeradius-ldap freeradius-mysql freeradius-postgresql
aptitude install freeradius freeradius-common freeradius-krb5 freeradius-utils

# 

export RADIUS_PWD="radius_pwd"
export R1=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;)
export R2=$(date +%s | sha256sum | base64 | head -c 32 ; echo)

export RAD_SECRET="$R1$R2"
echo "Generating secret...."
echo $RAD_SECRET

# == DataBase configuration =================
mysql -u root -p -e \
"CREATE DATABASE radius; GRANT ALL ON radius.* TO radius@localhost IDENTIFIED BY '$RADIUS_PWD'; \
flush privileges;"

mysql -uradius --password=$RADIUS_PWD radius  < /etc/freeradius/sql/mysql/schema.sql
mysql -uradius --password=$RADIUS_PWD radius  < /etc/freeradius/sql/mysql/nas.sql

# = Conf =======================

sed -i 's/password = "radpass"/password = "'$RADIUS_PWD'"/' /etc/freeradius/sql.conf
sed -i 's/#port = 3306/port = 3306/' /etc/freeradius/sql.conf
sed -i -e 's/$INCLUDE sql.conf/\n$INCLUDE sql.conf/g' /etc/freeradius/radiusd.conf
sed -i -e 's|$INCLUDE sql/mysql/counter.conf|\n$INCLUDE sql/mysql/counter.conf|g' /etc/freeradius/radiusd.conf
sed -i -e 's|authorize {|authorize {\nsql|' /etc/freeradius/sites-available/inner-tunnel
sed -i -e 's|session {|session {\nsql|' /etc/freeradius/sites-available/inner-tunnel 
sed -i -e 's|authorize {|authorize {\nsql|' /etc/freeradius/sites-available/default
sed -i -e 's|session {|session {\nsql|' /etc/freeradius/sites-available/default
sed -i -e 's|accounting {|accounting {\nsql|' /etc/freeradius/sites-available/default

# logging facilities
sed -i -e 's|auth_badpass = no|auth_badpass = yes|g' /etc/freeradius/radiusd.conf
sed -i -e 's|auth_goodpass = no|auth_goodpass = yes|g' /etc/freeradius/radiusd.conf
sed -i -e 's|auth = no|auth = yes|g' /etc/freeradius/radiusd.conf

# accounting (not tested)
sed -i -e 's|\t#  See "Authentication Logging Queries" in sql.conf\n\t#sql|#See "Authentication Logging Queries" in sql.conf\n\tsql|g' /etc/freeradius/sites-enabled/inner-tunnel 
sed -i -e 's|\t#  See "Authentication Logging Queries" in sql.conf\n\t#sql|#See "Authentication Logging Queries" in sql.conf\n\tsql|g' /etc/freeradius/sites-enabled/defaults

# logging sql when in debug mode
sed -i -e 's|sqltrace = no|sqltrace = yes|g' /etc/freeradius/sql.conf

# = client secret ===============
sed -i 's/testing123/'$RAD_SECRET'/' /etc/freeradius/clients.conf


sed -i -e "s/readclients = yes/nreadclients = yes" /etc/freeradius/clients.conf
echo -e "\nATTRIBUTE Usage-Limit 3000 string\nATTRIBUTE Rate-Limit 3001 string" >> /etc/freeradius/dictionary


# restart and status
systemctl restart freeradius.service
systemctl status freeradius.service
journalctl -xn


echo "Testing configuration"
mysql -uradius --password=$RADIUS_PWD radius  -e "USE radius; \
INSERT INTO radcheck ("username", "attribute", "op", "value") \
VALUES                 ('rad_usrtest','Cleartext-Password',':=','wuuserpas76');"

#radtest rad_usrtest wuazza56 127.0.0.1 0 $RAD_SECRET

# debug
#service freeradius stop
#freeradius -x

# PEAP needs NT-Password created with smbencrypt !

# eapol_test
# ./wpa_supplicant-2.5/wpa_supplicant/eapol_test  -a 10.87.7.213  -s SeCreTXXx -c eapol_test 
# ./wpa_supplicant-2.5/wpa_supplicant/eapol_test  -a 10.87.7.213  -s SeCreTXXx -c eapol_test.2 

# hashing NTLM password in python
# import hashlib,binascii
# hash = hashlib.new('md4', "password".encode('utf-16le')).digest()
# print binascii.hexlify(hash)

