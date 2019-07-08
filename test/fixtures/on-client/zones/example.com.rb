soa minimumTTL: 3600*12

template "ns"

a "@", "192.168.1.1"
a "a", "192.168.1.2", 3600
aaaa "2001:4860:4860::8888"
mx "mx1", 10
cname "www", "@"
