cd /path/to/downloaded/

wget https://archive.openwrt.org/barrier_breaker/14.07/ar71xx/mikrotik/openwrt-ar71xx-mikrotik-DefaultNoWifi-rootfs.tar.gz
wget https://archive.openwrt.org/barrier_breaker/14.07/ar71xx/mikrotik/openwrt-ar71xx-mikrotik-vmlinux-initramfs.elf
wget https://archive.openwrt.org/barrier_breaker/14.07/ar71xx/mikrotik/openwrt-ar71xx-mikrotik-vmlinux-lzma.elf

cp openwrt-ar71xx-mikrotik-DefaultNoWifi-rootfs.tar.gz openwrt-ar71xx-mikrotik-rootfs.tar.gz

cp * /srv/tftp

# Network configuration
export NETWORK=192.168.4.0
export GW=192.168.4.254
export BROADCAST=192.168.4.255
export DEV_MAC=d4:ca:6d:e6:6a:d7 # routerboard's mac address
export DHCP_SERVER=192.168.4.3
export CLIENT_IP=192.168.4.99 # given address to the client
export IMAGE_FNAME=openwrt-ar71xx-mikrotik-vmlinux-initramfs.elf
export IFNAME=eth2

# AFTPD configuration
cp /etc/default/atftpd atftpd.orig

echo "
USE_INETD=false
OPTIONS=\"--bind-address $DHCP_SERVER --tftpd-timeout 300 --retry-timeout 5 --mcast-port 1758 --mcast-addr 239.239.239.0-255 --mcast-ttl 1 --maxthread 100 --verbose=5 /srv/tftp\"
" > /etc/default/atftpd

/etc/init.d/atftpd restart

# DHCPD conf

cp /etc/dhcp/dhcpd.conf dhcpd.conf.orig

echo "
authoritative;
allow booting;
allow bootp;
one-lease-per-client true;

subnet $NETWORK netmask 255.255.255.0 {
  option routers $GW;
  option subnet-mask 255.255.255.0;
  option broadcast-address $BROADCAST;
  ignore client-updates;
}

group {
  host routerboard {
    hardware ethernet $DEV_MAC;
    next-server $DHCP_SERVER;
    fixed-address $CLIENT_IP;
    filename \"$IMAGE_FNAME\";
  }
}" > /etc/dhcp/dhcpd.conf

# stop NM and create your fake network before restarting isc-dhcp-server
/etc/init.d/network-manager stop
ifconfig $IFNAME $DHCP_SERVER/24
/etc/init.d/isc-dhcp-server restart

# check if tomcat or whatever is running on 8080 and should be stopped first
# this will serve rootfs fo wget2nand on openwrt devices
python3 -m http.server 8080

# now run wireshark on $IFNAME and
# unplug the DC cable from routerboard
# hold RES button while plug the DC cable (power on)
# wait untill you see BOOT_REQUEST and BOOT_REPLY on wireshark's captures

# now change routerboard port, port 1 will not work, move to another one
# configure an ip alias to manage your first connection
ifconfig $IFNAME:1 192.168.1.45/24
telnet 192.168.1.1

# on new openwrt 
wget2nand http://192.168.1.45:8080

