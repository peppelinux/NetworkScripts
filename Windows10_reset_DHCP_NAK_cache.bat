(Clear the dns cache)
ipconfig /flushdns

(release and refresh NetBIOS names)
nbtstat -RR 

(reset ip settings)
netsh int ip reset 

(Reset Winsock Catalog)
netsh winsock reset 
