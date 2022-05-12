#!/usr/bin/env bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/env.sh

if [[ ! -e $OPENVPNCONFIG ]] || [[ ! -r $OPENVPNCONFIG ]] || [[ ! -w $OPENVPNCONFIG ]]; then
    echo "$PPPCONFIG is not exist or not accessible (are you root?)"
    exit 1
fi

# DNS
echo
echo "Select a DNS server for the clients:"
echo "   1) Current system resolvers"
echo "   2) Google"
echo "   3) CloudFlare"
echo "   4) OpenDNS"
echo "   5) Quad9"
echo "   6) AdGuard"
read -p "DNS server [1]: " dns
until [[ -z "$dns" || "$dns" =~ ^[1-6]$ ]]; do
    echo "$dns: invalid selection."
    read -p "DNS server [1]: " dns
done

case "$dns" in
    1|"")
        # Locate the proper resolv.conf
        # Needed for systems running systemd-resolved
        if grep -q '^nameserver 127.0.0.53' "/etc/resolv.conf"; then
            resolv_conf="/run/systemd/resolve/resolv.conf"
        else
            resolv_conf="/etc/resolv.conf"
        fi
        # Obtain the resolvers from resolv.conf and use them for OpenVPN
        grep -v '^#\|^;' "$resolv_conf" | grep '^nameserver' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | while read line; do
            echo "push \"dhcp-option DNS $line\"" >> $OPENVPNCONFIG
        done
    ;;
    2)
        DNS1="8.8.8.8"
        DNS2="8.8.4.4"
    ;;
    3)
        DNS1="1.1.1.1"
        DNS2="1.0.0.1"
    ;;
    4)
        DNS1="208.67.222.222"
        DNS2="208.67.220.220"
    ;;
    5)
        DNS1="9.9.9.9"
        DNS2="149.112.112.112"
    ;;
    6)
        DNS1="94.140.14.14"
        DNS2="94.140.15.15"
    ;;
esac

# Keep compatibility with original variables
DEFAULTDNS1=$DNS1
DEFAULTDNS2=$DNS2

sed -i -e "/dhcp-option DNS/d" $OPENVPNCONFIG


# Prevent DNS leaks
echo "push \"ignore-unknown-option block-outside-dns\"" >> $OPENVPNCONFIG

echo "push \"dhcp-option DNS $DNS1\"" >> $OPENVPNCONFIG
echo "push \"dhcp-option DNS $DNS2\"" >> $OPENVPNCONFIG

echo "$OPENVPNCONFIG updated!"
