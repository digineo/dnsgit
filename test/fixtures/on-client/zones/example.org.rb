# We need a stable serial for tests. in production, you would want
# to leave the serial field untouched.
#
# Note: on Jan. 1st, 2125 the test suite will start to fail.
soa minimumTTL: "10m",
    serial:     2124_12_31_00

template "ns"

a "a", "192.168.1.3", 600 do
  cname "foo", 42   # foo 42 IN CNAME a
  cname "foo.bar"   # foo.bar IN CNAME a
  txt "a=b", 120    # @ 120 IN TXT "a=b"
end

aaaa "2001:4860:4860::6666"
mx "mx1", 10
mx "mx2", 20

a "b", "10.11.12.13", "2001:4860:4860::abcd" do
  cname "c", 60
end
