![Release](https://img.shields.io/badge/release-beta-orange.svg)
![Language](https://img.shields.io/badge/made%20with-bash-brightgreen.svg)
![License](https://img.shields.io/badge/license-GPLv3-blue.svg)
![LastUpdate](https://img.shields.io/badge/last%20update-2019%2F09-yellow.svg)

![logo](https://github.com/Leviathan36/SKA/blob/master/IMAGES/logo.png)

## About
SKA allows you to implement a very simple and fast [karma](https://en.wikipedia.org/wiki/KARMA_attack) attack.

You can sniff probe requests to choice the fake AP name or, if you want, you could insert manually the name of the AP ([evil twin attack](https://en.wikipedia.org/wiki/Evil_twin_(wireless_networks))).

When the target has connected to your WLAN you could active the HTTP redirection and perform a MITM attack.


## Details
The script implements these steps:

1. selection of NICs for the attack (one for LAN and one for WAN)
2. capture of probe-requests to choice the fake AP name (***tcpdump***)
3. activation of fake AP (***hostapd*** and ***dnsmasq***)
    
    * the new AP has a DHCP server which provides a valide IP to the target and prevents possible alerts on the victim devices
4. activation of HTTP redirection (***iptables***)

    * only HTTP requests are redirect to fake site, while the HTTPS traffic continues to route normally
6. activation of ***Apache*** server for hosting the phising site
7. at the end of the attack the script cleans all changes and restores Apache configuration


## Screenshots

<img src="https://github.com/Leviathan36/SKA/blob/master/IMAGES/complete_execution.png" alt="restore configuration files with CTRL-C" style="display: block;  margin-left: auto; margin-right: auto; width: 65%;">
<br><br>
Press CTRL-C to kill all processes and restore the configuration files. <br><br>
<img src="https://github.com/Leviathan36/SKA/blob/master/IMAGES/restoring_before_exit.png" alt="restore configuration files with CTRL-C" style="display: block;  margin-left: auto; margin-right: auto; width: 65%;">


## FAQ
SKA alerts you if there are some problems with NetworkManager demon or Apache configuration file. Anyway you could find the answers to your problems in the links below:

1. [resolve Network Manager conflict 1](https://rootsh3ll.com/evil-twin-attack/)

    section: "Resolve airmon-ng and Network Manager Conflict"

2. [resolve Network Manager conflict 2](https://github.com/sensepost/mana/issues/13)

3. [disable dnsmasq](https://unix.stackexchange.com/questions/257274/how-to-disable-dnsmasq)

#### In summary
1. Disable DNS line in your NetworkManager configuration file (look into /etc/NetworkManager/):

    ```#dns=dnsmasq```

2. Insert the MAC of your wireless adapter between the unmanaged devices to allow ***hostapd*** works properly:

    ```unmanaged-devices=mac:XX:XX:XX:XX:XX:XX```


<br>
<br>

-------------------------------------
## Disclaimer:
Author assume no liability and are not responsible for any misuse or damage caused by this program.

Kaboom is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

## License:
Kaboom is released under GPLv3 license. See [LICENSE](LICENSE) for more details.