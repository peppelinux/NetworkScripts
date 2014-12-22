export IFNAME=tun0;

insmod sch_htb
insmod sch_sfq
insmod cls_fw

# pulisco tutto
tc qdisc del dev $IFNAME root

# This line sets a HTB qdisc on the root of $IFNAME, and it specifies that the class 1:30 is used by default. It sets the name of the root as 1:, for future references.
tc qdisc add dev $IFNAME root handle 1: htb default 30

# This creates a class called 1:1, which is direct descendant of root (the parent is 1:), this class gets assigned also an HTB qdisc, and then it sets a max rate of 6mbits, with a burst of 15k
tc class add dev $IFNAME parent 1: classid 1:1 htb rate 12mbit burst 15k

# Class 1:10, which has a rate of 6mbit but 10mbit if anyone else are using internet
tc class add dev $IFNAME parent 1:1 classid 1:10 htb rate 6mbit ceil 8mbit burst 15k

# Class 1:20, which has a rate of 3mbit
tc class add dev $IFNAME parent 1:1 classid 1:20 htb rate 3mbit ceil 6mbit burst 15k

# Class 1:30, which has a rate of ...
tc class add dev $IFNAME parent 1:1 classid 1:30 htb rate 1mbit ceil 2mbit burst 15k

# controllo le classi inserite
#tc class show dev $IFNAME

# Martin Devera, author of HTB, then recommends SFQ for beneath these classes:
tc qdisc add dev $IFNAME parent 1:10 handle 10: sfq perturb 10
tc qdisc add dev $IFNAME parent 1:20 handle 20: sfq perturb 10
tc qdisc add dev $IFNAME parent 1:30 handle 30: sfq perturb 10

# adesso applico i filtri usando iptables
# creo un abbinamento, il mark 10 di ipt corrisponde al flowid 1:10 e via dicendo...

tc filter add dev $IFNAME protocol ip parent 1: prio 1 handle 10 fw flowid 1:10
tc filter add dev $IFNAME protocol ip parent 1: prio 1 handle 20 fw flowid 1:20
tc filter add dev $IFNAME protocol ip parent 1: prio 1 handle 30 fw flowid 1:30


# adesso assegno con iptables quello che preferisco
iptables -A PREROUTING -t mangle -i $IFNAME -j MARK --set-mark 20
#iptables -t mangle -L PREROUTING -n -v

# show hex in decimal
#printf '%d\n' 0x14
