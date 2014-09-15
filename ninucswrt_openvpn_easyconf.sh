#!/bin/sh

# /etc/openvpn or /etc/easy-rsa/keys ?
RSAPATH="/etc/openvpn/"

echo "
OpenVPN NinucsWRT tunnel setup
"

echo "Please enter your preferred openvpn server name without spaces: "
read SERVERNAME
echo "You entered: $SERVERNAME"

KEY_PATH="${RSAPATH}${SERVERNAME}/"
echo "$KEY_PATH"

#mkdir $KEY_PATH; echo "$KEY_PATH created"

if [ -d "$KEY_PATH" ]; then
  echo "this is the content of key directory of $SERVERNAME"
  ls $KEY_PATH
  if [ ! -f "${KEY_PATH}server.crt" ]; then 
    echo "ERROR: server.crt not found !"; exit  
  fi
  if [ ! -f "${KEY_PATH}ca.crt" ]; then 
    echo "ERROR: ca.crt not found !"; exit 
  fi
else
  printf "ERROR: $KEY_PATH doesn't exists !\n\n"
  exit 1
fi


printf "\n\nPlease enter your VPN network in this format:\n\t100.65.0.0 255.255.255.0\n"
read NETWORK
printf "You entered: $NETWORK\n\n"


# disabilito eventualmente il vecchio
/etc/init.d/openvpn stop
uci set openvpn.sample_server.enabled=0
#

uci set openvpn.$SERVERNAME=openvpn
uci set openvpn.$SERVERNAME.enabled=1
uci set openvpn.$SERVERNAME.port=1194
uci set openvpn.$SERVERNAME.proto=udp
uci set openvpn.$SERVERNAME.dev=tun
uci set openvpn.$SERVERNAME.ca=/etc/openvpn/$SERVERNAME/ca.crt
uci set openvpn.$SERVERNAME.cert=/etc/openvpn/$SERVERNAME/server.crt
uci set openvpn.$SERVERNAME.key=/etc/openvpn/$SERVERNAME/server.key
uci set openvpn.$SERVERNAME.dh=/etc/openvpn/$SERVERNAME/dh1024.pem
uci set openvpn.$SERVERNAME.server="$NETWORK"
uci set openvpn.$SERVERNAME.ifconfig_pool_persist=/tmp/ipp.txt
uci set openvpn.$SERVERNAME.push="redirect-gateway def1"
uci set openvpn.$SERVERNAME.keepalive="10 120"
uci set openvpn.$SERVERNAME.cipher=none
uci set openvpn.$SERVERNAME.comp_lzo=1
uci set openvpn.$SERVERNAME.persist_key=1
uci set openvpn.$SERVERNAME.persist_tun=1
uci set openvpn.$SERVERNAME.status=/tmp/openvpn-status.log
uci set openvpn.$SERVERNAME.verb=3

uci show openvpn.$SERVERNAME

echo "all the informations are correct ? (y/n)"
read RESPONSE
if [ "$RESPONSE" == "y" ]; then
   uci set network.VPN=interface
   uci set network.VPN.ifname=tun0
   uci set network.VPN.proto=none
   uci commit openvpn
   uci commit network
else
   uci revert openvpn
fi

/etc/init.d/openvpn reload
/etc/init.d/openvpn start
sleep 1
logread | tail -16 | grep openvpn

