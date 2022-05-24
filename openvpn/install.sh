#!/usr/bin/env bash

STARTDIR=$(pwd)

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# CUSTOMIZATION 0
	sed -i -e 's/OVPNPROTOCOL.*/OVPNPROTOCOL=udp/' $DIR/env.sh
	sed -i -e 's/OVPNPORT.*/OVPNPORT=1194/' $DIR/env.sh
#

source $DIR/env.sh

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi

echo
echo "Creating backup..."
$DIR/backup.sh

echo
echo "Installing OpenVPN..."
eval $PCKTMANAGER -y update
if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
	eval $INSTALLER epel-release
fi

eval $INSTALLER openvpn $CRON_PACKAGE $IPTABLES_PACKAGE procps net-tools

# Contains "semanage" to manage SELinux
if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
	
	if [ $(awk '{print $4}' /etc/centos-release) -ge 8 ]; then
		#Centos Stream 8,9 (minimal)
		eval $INSTALLER tar wget policycoreutils-python-utils
	else
		#Centos 7
		eval $INSTALLER policycoreutils-python
	fi
fi

# For UBUNTU 18.04 easy-rsa is still at 2.x branch, so it's ok
if [ "$PLATFORM" == "$DEBIANPLATFORM" ]; then
	eval $INSTALLER easy-rsa
fi
echo
echo "Configuring routing..."
$DIR/sysctl.sh

echo
echo "Installing configuration files..."
yes | cp -rf $DIR/openvpn-server.conf.dist $OPENVPNCONFIG

sed -i -e "s@OPENVPNDIR@$OPENVPNDIR@g" $OPENVPNCONFIG
sed -i -e "s@CADIR@$CADIR@g" $OPENVPNCONFIG
sed -i -e "s@LOCALPREFIX@$LOCALPREFIX@g" $OPENVPNCONFIG
sed -i -e "s@NOBODYGROUP@$NOBODYGROUP@g" $OPENVPNCONFIG

# CUSTOMIZATION 1
	$DIR/customize.sh
#

echo
echo "Configuring iptables firewall..."
$DIR/iptables-setup.sh

echo
echo "Configuring DNS parameters..."
$DIR/dns.sh

echo
echo "Creating server keys..."

if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
	# Get easy-rsa 2.2.2
	easy_rsa_url='https://github.com/OpenVPN/easy-rsa/releases/download/2.2.2/EasyRSA-2.2.2.tgz'
	mkdir -p /etc/openvpn/server/easy-rsa/
	{ wget -qO- "$easy_rsa_url" 2>/dev/null || curl -sL "$easy_rsa_url" ; } | tar xz -C /etc/openvpn/server/easy-rsa/ --strip-components 1
	chown -R root:root /etc/openvpn/server/easy-rsa/

	mkdir -p "$CADIR/keys"
	cp -rf /etc/openvpn/server/easy-rsa/* $CADIR
fi
if [ "$PLATFORM" == "$DEBIANPLATFORM" ]; then
	make-cadir $CADIR
	#Generate .rnd into home
	eval openssl rand -writerand ~/.rnd
fi

# workaround: Debian's openssl version is not compatible with easy-rsa
# using openssl-1.0.0.cnf if openssl.cnf not exists
cp -n /etc/openvpn/easy-rsa/openssl-1.0.0.cnf /etc/openvpn/easy-rsa/openssl.cnf

cd $CADIR
source ./vars
./clean-all
./build-ca
./build-key-server --batch openvpn-server
./build-dh
openvpn --genkey --secret ta.key

# add dummy user and revoke its certificate for non-empty crl.pem file
./build-key --batch client000
$DIR/deluser.sh client000

echo
echo "Adding cron jobs..."
yes | cp -rf $DIR/checkserver.sh $CHECKSERVER
$DIR/autostart.sh

cd $STARTDIR
echo
echo "Configuring VPN users..."
$DIR/adduser.sh

echo
echo "Starting OpenVPN..."
if [ "$PLATFORM" == "$CENTOSPLATFORM" ] && [ $(awk '{print $4}' /etc/centos-release) -ge 8 ]; then
	# It's needed to specify absolute path otherwise --config can't be readed
	sed -i 's/--config\ %i.conf/--config\ \/etc\/openvpn\/openvpn-server.conf/' /etc/systemd/system/multi-user.target.wants/openvpn-server@server.service
	
	systemctl -f enable openvpn-server@server
	systemctl restart openvpn-server@server
else
	systemctl -f enable openvpn@openvpn-server
	systemctl restart openvpn@openvpn-server
fi


echo
echo "Installation script has been completed!"
