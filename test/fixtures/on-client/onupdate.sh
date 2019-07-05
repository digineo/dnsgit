#!/bin/sh

set -e

for zone in $(echo $ZONES_CHANGED | sed "s/,/ /g"); do
	echo "processing ${zone} ... done"
done
