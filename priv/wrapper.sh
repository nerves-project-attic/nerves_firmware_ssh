#!/bin/sh
$@
EXIT=$?
# We don't have sleep..
dd if=/dev/zero of=/dev/null bs=100M count=10
exit $EXIT
