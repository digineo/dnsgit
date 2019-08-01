soa minimumTTL: "12h",
    serial:     2124_12_31_00

template "ns"

a "@", "192.168.1.1"
a "a", "192.168.1.2", 3600
aaaa "2001:4860:4860::8888"
mx "mx1", 10
cname "www", "@"
