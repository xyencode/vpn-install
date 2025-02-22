#!/usr/bin/env bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/env.sh

if [ "$PLATFORM" == "$CENTOSPLATFORM" ]; then
	systemctl enable iptables
	systemctl stop firewalld
	systemctl disable firewalld

    # Default iptables rules are injected from this file each time iptables is restarted
    # Because this action can break our firewall rules, must be removed. Empty file is created.
    # Maybe you can use these features for our purposes, for more information read:
    # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/security_guide/sec-setting_and_controlling_ip_sets_using_iptables
    if [[ ! -e /etc/sysconfig/iptables.backup ]]; then
	    mv /etc/sysconfig/iptables /etc/sysconfig/iptables.backup
        touch /etc/sysconfig/iptables
    fi
    #
    
	systemctl start iptables
fi

if [ "$PLATFORM" == "$DEBIANPLATFORM" ]; then
	systemctl stop ufw
	systemctl disable ufw
fi

COMMENT=" -m comment --comment \"$IPTABLES_COMMENT\""

if [[ ! -e $IPTABLES ]]; then
	touch $IPTABLES
fi

if [[ ! -e $IPTABLES ]] || [[ ! -r $IPTABLES ]] || [[ ! -w $IPTABLES ]]; then
    echo "$IPTABLES is not exist or not accessible (are you root?)"
    exit 1
fi

# clear existing rules
iptables-save | awk '($0 !~ /^-A/)||!($0 in a) {a[$0];print}' > $IPTABLES
sed -i -e "/--comment $IPTABLES_COMMENT/d" $IPTABLES
iptables -F
iptables-restore < $IPTABLES

IFS=$'\n'

iptablesclear=$(iptables -S -t nat | sed -n -e '/$LOCALPREFIX/p' | sed -e 's/-A/-D/g')
for line in $iptablesclear
do
    cmd="iptables -t nat $line"
    eval $cmd
done

# detect default gateway interface
echo "Found next network interfaces:"
ifconfig -a | sed 's/[: \t].*//;/^\(lo\|\)$/d'
echo
GATE=$(route | grep '^default' | grep -o '[^ ]*$')
read -p "Enter your external network interface: " -i $GATE -e GATE

STATIC="yes"
read -p "Your external IP is $IP. Is this IP static? [yes] " ANSIP
: ${ANSIP:=$STATIC}

if [ "$STATIC" == "$ANSIP" ]; then
    # SNAT
    sed -i -e "s@LEFTIP@$IP@g" $IPSECCONFIG
    sed -i -e "s@LEFTPORT@1701@g" $IPSECCONFIG
    sed -i -e "s@RIGHTIP@%any@g" $IPSECCONFIG
    sed -i -e "s@RIGHTPORT@%any@g" $IPSECCONFIG
    eval iptables -t nat -A POSTROUTING -s $LOCALIPMASK -o $GATE -j SNAT --to-source $IP $COMMENT
else
    # MASQUERADE
    sed -i -e "s@LEFTIP@%$GATE@g" $IPSECCONFIG
    sed -i -e "s@LEFTPORT@1701@g" $IPSECCONFIG
    sed -i -e "s@RIGHTIP@%any@g" $IPSECCONFIG
    sed -i -e "s@RIGHTPORT@%any@g" $IPSECCONFIG
    eval iptables -t nat -A POSTROUTING -o $GATE -j MASQUERADE $COMMENT
fi

DROP="yes"
read -p "Would you want to disable client-to-client routing? [yes] " ANSDROP
: ${ANSDROP:=$DROP}

if [ "$DROP" == "$ANSDROP" ]; then
    # disable forwarding
    eval iptables -I FORWARD -s $LOCALIPMASK -d $LOCALIPMASK -j DROP $COMMENT
else
    echo "Deleting DROP rule if exists..."
    eval iptables -D FORWARD -s $LOCALIPMASK -d $LOCALIPMASK -j DROP $COMMENT
fi

# Enable forwarding
eval iptables -A FORWARD -j ACCEPT $COMMENT

# MSS Clamping
eval iptables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS  --clamp-mss-to-pmtu $COMMENT

# PPP
eval iptables -A INPUT -i ppp+ -j ACCEPT $COMMENT
eval iptables -A OUTPUT -o ppp+ -j ACCEPT $COMMENT

# XL2TPD
#eval iptables -A INPUT -p tcp -m tcp --dport 1701 -j ACCEPT $COMMENT
#eval iptables -A INPUT -p udp -m udp --dport 1701 -j ACCEPT $COMMENT
#eval iptables -A OUTPUT -p tcp -m tcp --sport 1701 -j ACCEPT $COMMENT
#eval iptables -A OUTPUT -p udp -m udp --sport 1701 -j ACCEPT $COMMENT

# IPSEC
#eval iptables -A INPUT -p udp -m udp --dport 500 -j ACCEPT $COMMENT
#eval iptables -A INPUT -p udp -m udp --dport 4500 -j ACCEPT $COMMENT
#eval iptables -A INPUT -p esp -j ACCEPT $COMMENT
#eval iptables -A INPUT -p ah -j ACCEPT $COMMENT
#eval iptables -A OUTPUT -p tcp -m tcp --sport 1701 -j ACCEPT $COMMENT
#eval iptables -A OUTPUT -p udp -m udp --sport 1701 -j ACCEPT $COMMENT
#eval iptables -A OUTPUT -p esp -j ACCEPT $COMMENT
#eval iptables -A OUTPUT -p udp -m udp --sport 4500 -j ACCEPT $COMMENT
#eval iptables -A OUTPUT -p udp -m udp --sport 500 -j ACCEPT $COMMENT
#eval iptables -A OUTPUT -p ah -j ACCEPT $COMMENT

# CUSTOMIZATION 2
#
# I want to be able to choose whether or not to enable geoip blocking.
# If YES I must be able to choose the filtering logic: selective or exclusive.
# EXCLUSIVE it means accepting all nations except those on a list.
# SELECTIVE it means dropping all nations and accept only those on a list
# The cc.deny\allow files must contain the country-code list of the countries separated by a comma
# These iptables rules must be inserted above all others in the INPUT chain

    echo "GEOIP: Remember to modify cc.allow or cc.deny files (coma-separated) according to your needs!"
    echo
    GEOIP="no"
    read -p "GEOIP: Would you want to restrict access for L2TP by geographical locations? [no] " ANSGEOIP
    : ${ANSGEOIP:=$GEOIP}

    if [ "$GEOIP" == "$ANSGEOIP" ]; then
        # do nothing
        echo "You choose to accept PPTP connections from all over the world"
        eval iptables -A INPUT -p tcp -m tcp --dport 1701 -j ACCEPT $COMMENT
        eval iptables -A INPUT -p udp -m udp --dport 1701 -j ACCEPT $COMMENT
        eval iptables -A INPUT -p udp -m udp --dport 500 -j ACCEPT $COMMENT
        eval iptables -A INPUT -p udp -m udp --dport 4500 -j ACCEPT $COMMENT
        eval iptables -A INPUT -p esp -j ACCEPT $COMMENT
        eval iptables -A INPUT -p ah -j ACCEPT $COMMENT

    else
        # do something
        $DIR/geoip.sh
        echo
        echo "ATTENTION: Ok, GeoIP restrictions will be applied to L2TP VPN !!!"
        echo "Make sure you don't cut yourself off."
        echo "Complete the following survey..."
        echo
        echo
        echo "GEOIP: Please choose the operating mode between SELECTIVE (1) or EXCLUSIVE (2)"
        echo "       In SELECTIVE mode clients are allowed to connect only from specific countries."
        echo "       All other countries will be dropped."
        echo "       You MUST specify a list of country codes to allow inside **** cc.allow **** file"
        echo
        echo "       In EXCLUSIVE mode clients are rejected if try to connect from a specific countries,"
        echo "       but all other countries are accepted."
        echo "       You MUST specify a list of country codes to block inside **** cc.deny **** file"
        echo
        echo "       Format for cc.allow or cc.deny files is coma-separated i.e. US,CA,FR,DE,IT"
        echo
        echo
        echo
        read -p "GEOIP: Operating mode? [1]: " ANSMODE
        until [[ -z "$ANSMODE" || "$ANSMODE" =~ ^[12]$ ]]; do
			echo "$ANSMODE: invalid selection."
			read -p "GEOIP: Operating mode? [1]: " ANSMODE
		done
        case "$ANSMODE" in
			1|"") 
			#do selective
            readarray -t CC <$DIR/cc.allow
            eval iptables -I INPUT -p tcp -m tcp --dport 1701 -m geoip ! --src-cc ${CC[0]} -j DROP $COMMENT
            eval iptables -I INPUT -p udp -m udp --dport 1701 -m geoip ! --src-cc ${CC[0]} -j DROP $COMMENT
            eval iptables -I INPUT -p udp -m udp --dport 500 -m geoip ! --src-cc ${CC[0]} -j DROP $COMMENT
            eval iptables -I INPUT -p udp -m udp --dport 4500 -m geoip ! --src-cc ${CC[0]} -j DROP $COMMENT
            eval iptables -I INPUT -p esp -m geoip ! --src-cc ${CC[0]} -j DROP $COMMENT
            eval iptables -I INPUT -p ah -m geoip ! --src-cc ${CC[0]} -j DROP $COMMENT
            echo "Only these countries are allowed to connect: ${CC[0]}"
			;;
			2) 
			#do exclusive
            readarray -t CC <$DIR/cc.deny
            eval iptables -I INPUT -p tcp -m tcp --dport 1701 -m geoip --src-cc ${CC[0]} -j DROP $COMMENT
            eval iptables -I INPUT -p udp -m udp --dport 1701 -m geoip --src-cc ${CC[0]} -j DROP $COMMENT
            eval iptables -I INPUT -p udp -m udp --dport 500 -m geoip --src-cc ${CC[0]} -j DROP $COMMENT
            eval iptables -I INPUT -p udp -m udp --dport 4500 -m geoip --src-cc ${CC[0]} -j DROP $COMMENT
            eval iptables -I INPUT -p esp -m geoip --src-cc ${CC[0]} -j DROP $COMMENT
            eval iptables -I INPUT -p ah -m geoip --src-cc ${CC[0]} -j DROP $COMMENT
            echo "These countries will be rejected: ${CC[0]}"
			;;
		esac
    fi
    # Permit all outgoing vpn traffic (useless if the OUTPUT policy is already ALLOW)
    eval iptables -A OUTPUT -p tcp -m tcp --sport 1701 -j ACCEPT $COMMENT
    eval iptables -A OUTPUT -p udp -m udp --sport 1701 -j ACCEPT $COMMENT
    eval iptables -A OUTPUT -p esp -j ACCEPT $COMMENT
    eval iptables -A OUTPUT -p udp -m udp --sport 4500 -j ACCEPT $COMMENT
    eval iptables -A OUTPUT -p udp -m udp --sport 500 -j ACCEPT $COMMENT
    eval iptables -A OUTPUT -p ah -j ACCEPT $COMMENT
#

# remove standard REJECT rules
echo "Note: standard REJECT rules for INPUT and FORWARD will be removed."
iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited 2>/dev/null
iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited 2>/dev/null

iptables-save | awk '($0 !~ /^-A/)||!($0 in a) {a[$0];print}' > $IPTABLES
iptables -F
iptables-restore < $IPTABLES
