#!/bin/sh

#
# Upload new firmware to a target running nerves_firmware_ssh
#
# Usage:
#   upload.sh [destination IP] [Path to .fw file]
#
# If unspecifed, the destination is nerves.local and the .fw file
# is naively guessed
#
# You may want to add the following to your `~/.ssh/config` to avoid
# recording the IP addresses of the target:
#
# Host nerves.local
#   UserKnownHostsFile /dev/null
#   StrictHostKeyChecking no

set -e

DESTINATION=$1
FILENAME="$2"

[ -n "$DESTINATION" ] || DESTINATION=nerves.local
[ -n "$FILENAME" ] || FILENAME=$(ls ./_build/rpi0/dev/nerves/images/*.fw | head -1)

echo "Uploading $FILENAME to $DESTINATION..."

[ -f "$FILENAME" ] || (echo "Error: can't find $FILENAME"; exit 1)

FILESIZE=$(stat -c%s "$FILENAME")
printf "fwup:$FILESIZE,reboot\n" | cat - $FILENAME | ssh -s -p 8989 $DESTINATION nerves_firmware_ssh

