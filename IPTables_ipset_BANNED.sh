# apt install ipset

# create ipset defined by vulnerables networks (those are making DoS)
ipset -N banned iphash
ipset -A banned 185.36.216.0/22
ipset -A banned 194.247.26.0/23

# put this match in INPUT
iptables -I INPUT 2 -m set --match-set banned src -j DROP

# remove a network from the set
ipset del banned 185.36.216.0/22


