#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/env.sh

# Database directory (all generated and downloaded stuff will be put here)
DBDIR=/usr/share/xt_geoip

# Standard distribution location for xtables script, change if using custom
# For CENTOS 7.x with lastest updates
if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
	XT_GEOIP_BUILD=/usr/local/libexec/xtables-addons/xt_geoip_build
fi

# INSTALL PREREQUISITES
# For CENTOS 7.x with lastest updates
if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
	eval $INSTALLER gcc-c++ make automake kernel-devel-`uname -r` wget iptables-devel perl-Text-CSV_XS
fi
# For UBUNTU 18.04 with lastest updates
if [ "$PLATFORM" == "$DEBIANPLATFORM" ]; then
	eval $INSTALLER curl unzip perl xtables-addons-common libtext-csv-xs-perl libmoosex-types-netaddr-ip-perl
fi


# DB directory
mkdir -m 755 $DBDIR 2>/dev/null
test -w $DBDIR && cd $DBDIR 2>/dev/null || { echo "Invalid directory: $DBDIR"; exit 1; }

# Install XTABLES ADDONS
# For CENTOS 7.x with lastest updates
if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
	# Source material from inai.de/files/xtables-addons/
	cp $DIR/../xtables-addons-2.15.tar.xz $DBDIR/xtables-addons-2.15.tar.xz
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

# For UBUNTU 18.04 up to kernel 4.x
if [ "$PLATFORM" == "$DEBIANPLATFORM" ]; then
	if [ $(uname -r | awk -F . '{print $1}') -le 4  ]; then
		#Downloading updated database
		echo "updating xtables GeoIP database"
		# NOTE: at this point I should be in /usr/share/xt_geoip, just to be sure:
		cd $DBDIR

		# Source material from mailfud.org/geoip-legacy/
		cp $DIR/../GeoIP-legacy.csv.gz $DBDIR
		
		# Unpack (original .gz will be deleted with this command, no need to remove it afterward)
		gzip -d --force GeoIP-legacy.csv.gz

		#Building tables
		chmod +x /usr/lib/xtables-addons/xt_geoip_build
		/usr/lib/xtables-addons/xt_geoip_build -D /usr/share/xt_geoip/ $DBDIR/GeoIP-legacy.csv
		rm $DBDIR/GeoIP-legacy.csv

		#Test
		if modprobe xt_geoip >/dev/null 2>&1; then echo "Module xt_geoip loaded"; else echo "Failed to modprobe xt_geoip"; fi;
	else
		echo "The kernel version is too new. Unable to install legacy xtables and geoip. Also PPTP and L2TP do not work on kernels >= 5.x"
		echo "Revert to a previous kernel 4.x and reinstall this vpn script"
		exit 0
	fi
fi

# Return to the fold
cd $DIR
