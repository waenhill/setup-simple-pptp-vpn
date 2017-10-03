#!/bin/sh
#    Setup Simple PPTP VPN server for Ubuntu and Debian
#    Copyright (C) 2013-2015 Viljo Viitanen <viljo.viitanen@iki.fi> and contributors
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#    2013-11-06: initial version. Tested with Amazon EC2 Ubuntu 12.04 and 
#                Digital Ocean Debian 7.0 and Ubuntu 12.04 images.
#    2014-03-23: Added apt-get update.
#    2014-09-18: Add help, allow custom username and password, thanks to dileep-p
#    2015-01-25: Change external ip provider, thanks to theroyalstudent
#    2017-10-03: Modification done for Debian (mondedie.fr)

printhelp() {

echo "
Usage: sh setup.sh [OPTION]
If you are using custom password , Make sure its more than 8 characters. Otherwise it will generate random password for you. 
If you trying set password only. It will generate Default user with Random password. 
example: sudo bash setup.sh -u vpn -p mypass
Use without parameter [ sudo bash setup.sh ] to use default username and Random password
  -u,    --username             Enter the Username
  -p,    --password             Enter the Password
"
}

while [ "$1" != "" ]; do
  case "$1" in
    -u    | --username )             NAME=$2; shift 2 ;;
    -p    | --password )             PASS=$2; shift 2 ;;
    -h    | --help )            echo "$(printhelp)"; exit; shift; break ;;
  esac
done

if [ `id -u` -ne 0 ] 
then
  echo "Need root, try with sudo"
  exit 0
fi

echo
echo "######################################################"
echo "Downloading and Installing PoPToP"
echo "######################################################"
apt-get update

apt-get -y install pptpd || {
  echo "Could not install pptpd" 
  exit 1
}


#no liI10oO chars in password

LEN=$(echo ${#PASS})

if [ -z "$PASS" ] || [ $LEN -lt 8 ] || [ -z "$NAME"]
then
   P1=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   P2=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   P3=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   PASS="$P1-$P2-$P3"
fi

if [ -z "$NAME" ]
then
   NAME="vpn"
fi

echo
echo "######################################################"
echo "Creating Server Config"
echo "######################################################"

# get the VPS IP
ip=`ifconfig eth0 | grep 'inet adr' | awk {'print $2'} | sed s/.*://`

cp /etc/ppp/chap-secrets /etc/ppp/chap-secrets.bak
cat >/etc/ppp/chap-secrets <<END
# Secrets for authentication using CHAP
#client	server	secret	IP	addresses
$NAME	pptpd	$PASS	*
waenhill	pptpd	niamoR24.	*
waen	pptpd	niamoR24.	*
waentorrents	pptpd	Romain24	*
visiteur	pptpd	pute	*
END

cp /etc/pptpd.conf /etc/pptpd.conf.bak
cat >/etc/pptpd.conf <<END
option /etc/ppp/pptpd-options
logwtmp
localip $ip	#192.168.2.1
remoteip 192.168.2.10-100
END

cp /etc/ppp/pptpd-options /etc/ppp/pptpd-options.bak
cat >/etc/ppp/pptpd-options <<END
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
ms-dns 80.67.169.12
ms-dns 80.67.169.40
proxyarp
lock
nobsdcomp 
novj
novjccomp
nologfd
END

echo
echo "######################################################"
echo "Forwarding IPv4 and Enabling it on boot"
echo "######################################################"
cp /etc/sysctl.conf /etc/sysctl.conf.bak
cat >> /etc/sysctl.conf <<END
net.ipv4.ip_forward=1
END
sysctl -p

echo
echo "######################################################"
echo "Updating IPtables Routing and Enabling it on boot"
echo "######################################################"
iptables -t nat -A POSTROUTING -j SNAT --to $ip
# saves iptables routing rules and enables them on-boot
iptables-save -c > /etc/iptables.conf

cat > /etc/network/if-pre-up.d/iptables <<END
#!/bin/sh
iptables-restore < /etc/iptables.conf
END

chmod +x /etc/network/if-pre-up.d/iptables
cat >> /etc/ppp/ip-up <<END
ifconfig ppp0 mtu 1400
END

echo
echo "######################################################"
echo "Restarting PoPToP"
echo "######################################################"
sleep 5
service pptpd restart

echo
echo "######################################################"
echo "Check server configurations"
echo "######################################################"
apt-get -y install wget || {
  echo "Could not install wget, required to retrieve your IP address." 
  exit 1
}

#find out external ip 
cd /tmp
IP=`wget -q -O - http://api.ipify.org`

if [ "x$IP" = "x" ]
then
  echo "============================================================"
  echo "  !!!  COULD NOT DETECT SERVER EXTERNAL IP ADDRESS  !!!"
else
  echo "============================================================"
  echo "Detected your server external ip address: $IP"
fi
echo   ""
echo   "VPN username = $NAME   password = $PASS"
echo   "============================================================"
sleep 2

service pptpd restart

exit 0
