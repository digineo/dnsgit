# We need a stable serial for tests. in production, you would want
# to leave the serial field untouched.
#
# Note: on Jan. 1st, 2125 the test suite will start to fail.
soa serial: 2124_12_31_00

template "ns"

ptr 53, "ns.localhost."
