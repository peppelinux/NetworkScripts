CLIENT SIDE - SETTING UP A MANUAL SSH TUNNEL

#Open a SSH connection (10.0.0.2 = IP server SSH)
   sudo ssh root@10.1.0.2 -w 0:0

#Configure IP tun0
   sudo ifconfig tun0 10.1.0.131 pointopoint 10.1.0.132 up

#Add matching route to the subnet where 10.0.0.132 is inserted
   sudo route add -net 10.0.0.128/25 gw 10.0.0.132


CLIENT SIDE - SETTING UP A PERMANENT SSH TUNNEL

#Generating a RSA key pair with empty passphrase
ssh-keygen -f vpnloginkey -N ""

#Copy this key to the SSH server (to be done BEFORE the password login mode is disabled on the server)
ssh-copy-id -i ./vpnloginkey root@10.1.0.2

#Test if the login with RSA works
ssh -i vpnloginkey root@10.1.0.2

#Add to /etc/network/interfaces the lines
-----
   iface tun0 inet static
        pre-up sleep 5
        address 10.1.0.131
        pointopoint 10.1.0.132
        netmask 255.255.255.255
        up route add -net 10.1.0.128/25 gw 10.1.0.132
-----

#Create the executable script loginvpn.sh containing lines
   sudo ssh -NTCf -i vpnloginkey root@10.1.0.2 -w 0:0
   sudo ifdown tun0
   sudo ifup tun0

#Alternative - if the command in /root/.ssh/authorized_keys not work
#Create the executable script loginvpn.sh containing lines
# Remember to delere in server side "no-port-forwarding,no-X11-forwarding,no-agent-forwarding" in /root/.ssh/authorized_keys file
   sudo ssh -TCf -i vpnloginkey root@10.1.0.2 -w 0:0 ifdown tun0 ifup tun0
   sudo ifdown tun0
   sudo ifup tun0
  
   

#The SSH options above mean:

 -N Means that the SSH command line there are no commands to be given to the server
(the only command that will be executed is predetermined in /root/.ssh/authorized_keys on the server)

 -T Means that it is not required to open a terminal on the remote machine

 -C Enables data compression. Generally improves performance

 -f The SSH channel remains open and the SSH command is put in the background.

#Run the script ... connection successful. (hopefully)

#Close the connection
sudo pkill -f vpnlogin
