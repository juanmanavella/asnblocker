#!/bin/bash

# Mass domain blocker for your firewall/router. It works by rejecting traffic on the FORWARD chain.
# Using your provided domain.tld, the ASN for the entire organization will be resolved and further,
# all traffic being forwarded to the entire range of assigned IP numbers for that AS blocked.


# User prompt check:

if [[ "$1" != "" ]]; then
	DOMAIN="$1"
    else
	printf "\nYou must provide an argument: `basename $0` domain.tld\n" 
	printf "Example: `basename $0` facebook.com\n\n" 
    exit 1
fi

# Log file init:
SCRIPTNAME=`basename $0`
touch $SCRIPTNAME.log 
# If exists, clear it:
> $SCRIPTNAME.log


# Get the IP address for the given domain.tld:

IP=`host $DOMAIN | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | cut -d$'\n' -f1`


# Check if the given IP is part of Cloudflare/Amazon:

if [ -n "`whois $IP | grep -E "cloudflare.com|amazon.com"`" ]; then
	echo "The given domain is behind Cloudflare or hosted in Amazon."
	read -r -p "Do you want to block the entire AS anyway? [y/N]" cfprompt
	  
	  if [[ $cfprompt =~ [yY](es)* ]]; then
	  echo "Be aware: you may be blocking half of the internet by doing this"
	  else
	    exit 1
	  fi
fi


### IANA Query section:
# Get the first AS number for that route from the given IP address:

ASN=`whois -h whois.radb.net -T route $IP | grep origin | cut -d$'\n' -f1 | cut -d " " -f2-`

# Get the Organization name for the about to be blocked ranges:
ASN_RANGE_COUNT=`whois -h whois.radb.net -- "-i origin $ASN" | grep "descr:" -c`
ASN_ORG=`whois -h whois.radb.net -- "-i origin $ASN" | grep "descr:" |cut -d " " -f2- | sort | uniq | grep -Ev '[0-9]+' | tr -d '\040\011' | uniq`


# Another warning:
printf "\nOk, given your provided $DOMAIN, you are about to block $ASN_RANGE_COUNT IP address ranges\n"
printf "belonging to the following organization(s):\n\n$ASN_ORG\n\n"

read -r -p "Are you sure? [y/N]" fatalityprompt

 if [[ $fatalityprompt =~ [yY](es)* ]]; then
   for i in `whois -h whois.radb.net -- "-i origin $ASN" | grep "^route:" | cut -d ":" -f2 | xargs | tr " " "\n"`
     do 
      echo "iptables -I FORWARD -p all -d $i -j REJECT" >> $SCRIPTNAME.log
      iptables -I FORWARD -p all -d $i -j REJECT
   done
   printf "\n\nDone. Check the iptables commands in $SCRIPTNAME.log\n\n\n"
   echo 'To revert all the changes issue: for i in `whois -h whois.radb.net -- "-i origin '$ASN'" | grep "^route:" | cut -d ":" -f2 | xargs | tr " " "\n"`; do iptables -D FORWARD -p all -d $i -j REJECT; done'
   printf '\n\nExample to unblock some IP or range:\n\n' 
   echo 'Unblock two ip addresses: for i in `whois -h whois.radb.net -- "-i origin '$ASN'" | grep "^route:" | cut -d ":" -f2 | xargs | tr " " "\n"`; do iptables -I FORWARD -p all -s 10.0.0.30,10.0.0.31 -d $i -j ACCEPT; done'
   echo 'Unblock a range: for i in `whois -h whois.radb.net -- "-i origin '$ASN'" | grep "^route:" | cut -d ":" -f2 | xargs | tr " " "\n"`; do iptables -I FORWARD -p all -s 10.0.0.45-55 -d $i -j ACCEPT; done'
   echo 'Unblock a subnet: for i in `whois -h whois.radb.net -- "-i origin '$ASN'" | grep "^route:" | cut -d ":" -f2 | xargs | tr " " "\n"`; do iptables -I FORWARD -p all -s 192.168.1.0/24 -d $i -j ACCEPT; done'
 else
   exit 1
 fi



