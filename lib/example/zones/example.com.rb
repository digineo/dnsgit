
soa minimumTTL: 3600*12

template "example-dns"

# A records
a "a.ns", "192.168.1.2", 3600
a "b.ns", "192.168.1.3", 3600
a "mx1", "192.168.1.11"
a "mx2", "192.168.1.12"
a "sipserver", "192.168.1.200"

# AAAA records
aaaa "2001:4860:4860::8888"

# MX records
mx "mx1", 10
mx "mx2", 20

# CNAME records
cname "www", "@"
txt "google-site-verification=vEj1ZcGtXeM_UEjnCqQEhxPSqkS9IQ4PBFuh48FP8o4"

# SRV records
srv :sip, :tcp, "sipserver.example.net.", 5060

# TLSA record
tlsa 443, :tcp, "@", 0, 0, 1, "e36d9e402c6308273375b68297f7ae207521238f0cd812622672f0f2ce67eb1c"

# Wildcard records
a "*.user", "192.168.1.100"
mx "*.user", "mail"
