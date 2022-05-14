#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/env.sh

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi

TMPFILE=$(mktemp crontab.XXXXX)
crontab -l > $TMPFILE

RESTOREPATH=$(which iptables-restore)
RESTORPRESENTS=$(grep iptables-restore $TMPFILE)

#OLD CODE
# if [ $? -ne 0 ]; then
# 	echo "@reboot $RESTOREPATH <$IPTABLES >/dev/null 2>&1" >> $TMPFILE
# fi

# When the kernel is updated or a different kernel is booted, the geoip module may stop working on CentOS as it is not compiled specifically for that version. In that case, restoring the rules saved via iptables-restore fails. It is therefore necessary to take action and recompile them for the current kernel in use. To do this, just re-run any of the three geoip.sh since they are currently identical.
if [ $? -ne 0 ]; then
	echo "@reboot if ! $RESTOREPATH <$IPTABLES >/dev/null 2>&1 ; then /bin/bash $DIR/geoip.sh ; $RESTOREPATH <$IPTABLES ; fi ; " >> $TMPFILE
fi

SERVERSPRESENTS=$(grep "$CHECKSERVER" $TMPFILE)
if [ $? -ne 0 ]; then
	echo "*/5 * * * * $CHECKSERVER >/dev/null 2>&1" >> $TMPFILE
fi

crontab $TMPFILE > /dev/null
rm $TMPFILE
