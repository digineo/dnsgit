soa minimumTTL: "10m",
    serial:     2124_12_31_00

template "ns"

a "a", "192.168.1.3", 600
aaaa "2001:4860:4860::6666"
mx "mx1", 10
mx "mx2", 20

a do
  cname "foo", 42
  cname "foo.bar"
  txt "a=b", 120
end

a "b", "10.11.12.13", "2001:4860:4860::abcd" do
  cname "c", 60
end
