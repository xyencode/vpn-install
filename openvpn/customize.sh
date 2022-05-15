#!/usr/bin/env bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/env.sh

# Freely copied and adapted from github.com/Nyr/openvpn-install/blob/master/openvpn-install.sh
# BEGIN CUSTOMIZATION 1
	# PROTO
		echo
		echo "Which protocol should OpenVPN use?"
		echo "   1) UDP (recommended)"
		echo "   2) TCP"
		read -p "Protocol [1]: " VPNPRTCL
		until [[ -z "$VPNPRTCL" || "$VPNPRTCL" =~ ^[12]$ ]]; do
			echo "$VPNPRTCL: invalid selection."
			read -p "Protocol [1]: " VPNPRTCL
		done
		case "$VPNPRTCL" in
			1|"")
			#Server
			sed -i -e 's/proto.*/proto udp/' $OPENVPNCONFIG
			#Client
			sed -i -e 's/proto.*/proto udp/' $DIR/openvpn-server.ovpn.dist
			sed -i -e 's/proto.*/proto udp/' $DIR/openvpn-server-embedded.ovpn.dist
            VPNPRTCL=udp
			;;
			2)
			#Server
			sed -i -e 's/proto.*/proto tcp/' $OPENVPNCONFIG
			#Client
			sed -i -e 's/proto.*/proto tcp/' $DIR/openvpn-server.ovpn.dist
			sed -i -e 's/proto.*/proto tcp/' $DIR/openvpn-server-embedded.ovpn.dist
            VPNPRTCL=tcp
			;;
		esac

	# PORT
		echo
		echo "What port should OpenVPN listen to?"
		read -p "Port [1194]: " VPNPRT
		until [[ -z "$VPNPRT" || "$VPNPRT" =~ ^[0-9]+$ && "$VPNPRT" -le 65535 ]]; do
			echo "$VPNPRT: invalid port."
			read -p "Port [1194]: " VPNPRT
		done
		[[ -z "$VPNPRT" ]] && VPNPRT="1194"
		#Server
		sed -i -e "s/port.*/port $VPNPRT/" $OPENVPNCONFIG
		#Client
		sed -i -e "s/port.*/port $VPNPRT/" $DIR/openvpn-server.ovpn.dist
		sed -i -e "s/port.*/port $VPNPRT/" $DIR/openvpn-server-embedded.ovpn.dist

    # FINAL EDIT env.sh
        sed -i -e "s/OVPNPROTOCOL.*/OVPNPROTOCOL=$VPNPRTCL/" $DIR/env.sh
        sed -i -e "s/OVPNPORT.*/OVPNPORT=$VPNPRT/" $DIR/env.sh

	# SELINUX
	# To be able to run openvpn on custom proto\port, selinux context must be adapted adding these values, default value will be ignored
	# Utility "semanage" is part of "policycoreutils-python package"
	if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
		eval semanage port -a -t openvpn_port_t -p $VPNPRTCL $VPNPRT
	fi

# END CUSTOMIZATION 1
