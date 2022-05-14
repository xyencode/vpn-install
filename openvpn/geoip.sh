#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/env.sh

# Database directory (all generated and downloaded stuff will be put here)
DBDIR=/usr/share/xt_geoip

# Files to download (UNUSED VARIABLE)
XTABLES="GeoIP-legacy.csv"

# Standard distribution location for xtables script, change if using custom
# For CENTOS 7.x with lastest updates
if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
	XT_GEOIP_BUILD=/usr/local/libexec/xtables-addons/xt_geoip_build
fi

# INSTALL PREREQUISITES
# For CENTOS 7.x with lastest updates
if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
	#eval $INSTALLER install gcc-c++ make automake kernel-devel-`uname -r` wget iptables-devel perl-Text-CSV_XS
	eval $INSTALLER install gcc-c++ make automake kernel-devel-3.10.0-1160.el7 wget iptables-devel perl-Text-CSV_XS
fi

# DB directory
mkdir -m 755 $DBDIR 2>/dev/null
test -w $DBDIR && cd $DBDIR 2>/dev/null || { echo "Invalid directory: $DBDIR"; exit 1; }

# Install XTABLES ADDONS
# For CENTOS 7.x with lastest updates
if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
	# Source material from inai.de/files/xtables-addons/
	cp $DIR/../xtables-addons-2.15.tar.xz $DBDIR/xtables-addons-2.15.tar.xz
	#wget https://github.com/xyencode/vpn-install/raw/master/xtables-addons-2.15.tar.xz -O $DBDIR/xtables-addons-2.15.tar.xz
	tar xf $DBDIR/xtables-addons-2.15.tar.xz -C $DBDIR && rm $DBDIR/xtables-addons-2.15.tar.xz
	cd $DBDIR/xtables-addons-2.15

	# Disable TARPIT module because of compile errors on CentOS (also is not useful for our scope) as discovered here xinet.kr/?p=2132

	sed -i 's/build_TARPIT=m/#build_TARPIT=m/' ./mconfig

	# Continue with installation
	./configure
	make
	make install

	rm -rf $DBDIR/xtables-addons-2.15

	# NOTE: at this point I should be in /usr/share/xt_geoip, just to be sure:
	cd $DBDIR


	# Source material from mailfud.org/geoip-legacy/
	cp $DIR/../GeoIP-legacy.csv.gz $DBDIR
	#wget -T 30 https://github.com/xyencode/vpn-install/raw/master/GeoIP-legacy.csv.gz -O GeoIP-legacy.csv.gz
	# RET=$?
	# if [ $RET -ne 0 ]; then
	# 	echo "wget GeoIP-legacy.csv.gz failed: $RET" >&2
	#	
	# 	# Continue because the archive may be previously or manually downloaded
	# 	continue
	# fi
	
	# Unpack (original .gz will be deleted with this command, no need to remove it afterward)
	gzip -d --force GeoIP-legacy.csv.gz

	echo "updating xtables GeoIP database"

	if [ ! -f "$XT_GEOIP_BUILD" ]; then
		echo "xt_geoip_build not found, xtables addons not installed?" >&2
		exit 0
	fi
	if [ ! -f "GeoIP-legacy.csv" ]; then
		echo "GeoIP-legacy.csv not found, cannot update xt_geoip" >&2
		exit 0
	fi

	# Prepare PERL command
	XCMD="perl $XT_GEOIP_BUILD -D /usr/share/xt_geoip $DBDIR/GeoIP-legacy.csv"

	# Tables building + simply check
	RET=$($XCMD 2>/dev/null | tail -1)
	if [[ "$RET" =~ (Zimbabwe|ZW) ]]; then
		echo "xt_geoip updated"
	else
		echo "something went wrong with xt_geoip update" >&2
		echo "do you have perl module Text::CSV_XS / libtext-csv-xs-perl installed?" >&2
		echo "try running command manually:" >&2
		echo "$XCMD" >&2
	fi
fi

# For UBUNTU 18.04 with lastest updates
#··························· >> TODO <<

# Return to the fold
cd $DIR
