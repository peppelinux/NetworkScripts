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
echo "You entered: $NETWORK"

uci set openvpn.sample_server=openvpn
uci set openvpn.sample_server.enabled=1
uci set openvpn.sample_server.port=1194
uci set openvpn.sample_server.proto=udp
uci set openvpn.sample_server.dev=tun
uci set openvpn.sample_server.ca=/etc/openvpn/$SERVERNAME/ca.crt
uci set openvpn.sample_server.cert=/etc/openvpn/$SERVERNAME/server.crt
uci set openvpn.sample_server.key=/etc/openvpn/$SERVERNAME/server.key
uci set openvpn.sample_server.dh=/etc/openvpn/$SERVERNAME/dh1024.pem
uci set openvpn.sample_server.server="$NETWORK"
uci set openvpn.sample_server.ifconfig_pool_persist=/tmp/ipp.txt
uci set openvpn.sample_server.push="redirect-gateway def1"
uci set openvpn.sample_server.keepalive="10 120"
uci set openvpn.sample_server.cipher=none
uci set openvpn.sample_server.comp_lzo=1
uci set openvpn.sample_server.persist_key=1
uci set openvpn.sample_server.persist_tun=1
uci set openvpn.sample_server.status=/tmp/openvpn-status.log
uci set openvpn.sample_server.verb=3

uci show openvpn.sample_server

echo "all the informations are correct ? (y/n)"
read RESPONSE
if [ "$RESPONSE" == "y" ]; then
   uci commit openvpn
else
   uci delete openvpn.sample_server
fi

/etc/init.d/openvpn reload
/etc/init.d/openvpn stop
/etc/init.d/openvpn start

sleep 2
logread | grep openvpn
