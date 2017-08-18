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
#
# Feel free to copy this script whereever is convenient. The original
# is at https://github.com/fhunleth/nerves_firmware_ssh/blob/master/upload.sh
#

set -e

DESTINATION=$1
FILENAME="$2"

help() {
    echo
    echo "upload.sh [destination IP] [Path to .fw file]"
    exit 1
}

[ -n "$DESTINATION" ] || DESTINATION=nerves.local
[ -n "$MIX_TARGET" ] || MIX_TARGET=rpi0
[ -n "$FILENAME" ] || FILENAME=$(ls ./_build/$MIX_TARGET/dev/nerves/images/*.fw | head -1)

echo "Uploading $FILENAME to $DESTINATION..."

[ -f "$FILENAME" ] || (echo "Error: can't find '$FILENAME'"; help)

case "$(uname -s)" in
    Darwin|FreeBSD|NetBSD|OpenBSD|DragonFly)
	# BSD stat
        FILESIZE=$(stat -f %z "$FILENAME")
        ;;
    *)
	# GNU stat
        FILESIZE=$(stat -c%s "$FILENAME")
        ;;
esac

# Workaround for https://bugs.erlang.org/browse/ERL-469
unset SSH_AUTH_SOCK

# Don't fall back to asking for passwords, since that won't work
# and it's easy to misread the message thinking that it's asking
# for the private key password
SSH_OPTIONS="-o PreferredAuthentications=publickey"

if [ "$(uname -s)" = "Darwin" ]; then
    DESTINATION_IP=$(arp -n $DESTINATION | sed 's/.* (\([0-9.]*\).*/\1/' || exit 0)
    if [ -z "$DESTINATION_IP" ]; then
        echo "Can't resolve $DESTINATION"
        exit 1
    fi

    IS_DEST_LL=$(echo $DESTINATION_IP | grep '^169\.254\.')
    if [ -n "$IS_DEST_LL" ]; then
        LINK_LOCAL_IP=$(ifconfig | grep 169.254 | sed 's/.*inet \([0-9.]*\) .*/\1/')
        if [ -z "$LINK_LOCAL_IP" ]; then
            echo "Can't find an interface with a link local address?"
            exit 1
        fi

        # If a link local address, then force ssh to bind to the link local IP
        # when connecting. This fixes an issue where the ssh connection is bound
        # to another Ethernet interface. The TCP SYN packet that goes out has no
        # chance of working when this happens.
        SSH_OPTIONS="$SSH_OPTIONS -b $LINK_LOCAL_IP"
    fi
fi

printf "fwup:$FILESIZE,reboot\n" | cat - $FILENAME | ssh -s -p 8989 $SSH_OPTIONS $DESTINATION nerves_firmware_ssh

