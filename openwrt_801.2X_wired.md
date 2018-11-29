Configuring 802.1X Wired auth on OpenWRT/LEDE
---------------------------------------------

- Uninstall wpda-mini
- install wpad

Configure the connection
------------------------
````
# in /etc/config/wpa_wired.conf
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=root
ap_scan=0
network={
        key_mgmt=IEEE8021X
        eap=MSCHAPV2
        eapol_flags=0
        identity="Your LOGIN"
        password="Your PASSWORD"
        phase1="peaplabel=1"
        phase2="auth=MSCHAPV2"
}
````

Enable on boot
--------------

Create /etc/init.d/wpa_wired
````
#!/bin/sh /etc/rc.common
 
START=99
 
start() {
    echo start
    wpa_supplicant -D wired -i eth0 -c /etc/config/wpa_wired.conf &
}
````

Set the correct permissions
````
chmod +x /etc/init.d/wpa_wired
chmod 755 /etc/init.d/wpa_wired
/etc/init.d/wpa_wired enable 
````
