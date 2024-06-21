#!/bin/bash

printf "\e[93m==== awg-remove-peer by CrPO4 ====\e[0m\n"

if [ "$1" == "--help" ]; then 
    printf "Interactive mode: run without parameters.\n";
    printf "Inline mode: ./awg-remove-peer.sh /path/to/amnezia interfaceName peerName\n";
    exit 0;
fi

if [ "$#" -ne 0 ] && [ "$#" -ne 3 ]; then
  echo "Error: This script requires either 0 or 3 non-empty arguments.";
  exit 1;
fi

declare logFile
logFile=$(pwd)/awg-remove-peer.log

announceAction() {
printf "Action %s: \e[93m$2...\e[0m\n" "$1"
printf "==== STEP %s ====\n" "$1" >> "$logFile"
}

logAction() {
if [ $? -eq 0 ]; then
   printf "Result %s: \e[92mSuccess.\e[0m\n" "$1";
else
   printf "Result %s: \e[32mFailure.\e[0m Please review $logFile at step %s.\n" "$1" "$1";
   exit 4;
fi
}

announceAction 001 "Making log file"
touch "$logFile"
logAction 001 "Warning 001: From now on, almost all output will be made to $logFile."
announceAction 002 "Setting terminal to non-interactive mode"
export DEBIAN_FRONTEND=noninteractive
logAction 002
announceAction 003 "Requesting user data"
declare amneziaPath
if [ -n "$1" ]; then 
    amneziaPath="$1"; 
else
    amneziaPath="/opt/amnezia"
    printf "            Path to Amnezia configuration files [%s]: " "$amneziaPath"; read -r tempAmneziaPath
    if [ -n "$tempAmneziaPath" ]; then amneziaPath="$tempAmneziaPath"; fi
fi
declare interfaceName
if [ -n "$2" ]; then 
    interfaceName="$2"; 
else
    interfaceName="awg0"
    printf "            Interface name to adjust [%s]: " "$interfaceName"; read -r tempInterfaceName
    if [ -n "$tempInterfaceName" ]; then interfaceName="$tempInterfaceName"; fi
fi
declare peerName
if [ -n "$3" ]; then 
    peerName="$3"; 
else
peerName="UserDevice"
printf "            Peer name [%s]: " "$peerName"; read -r tempPeerName
if [ -n "$tempPeerName" ]; then peerName="$tempPeerName"; fi
fi

logAction 003
announceAction 004 "Finding peer address"
declare peerPublicKey
peerPublicKey=$(<"$amneziaPath"/clients/"$interfaceName"-"$peerName".key.pub)
peerAddress=$("$amneziaPath/binaries/awg" show "$interfaceName" allowed-ips | grep "$peerPublicKey" | awk -F '\t' '{print $2}' | awk -F '.' '{print $4}' | awk -F '/' '{print $1}')
logAction 004
announceAction 004 "Removing peer"
"$amneziaPath/binaries/awg" set "$interfaceName" peer "$peerPublicKey" remove
rm -f "$amneziaPath/clients/$interfaceName-$peerName.*"
announceAction 005 "Updating IP pool"
echo "$peerAddress" >> "$amneziaPath/server/$interfaceName.pool"
sort -gr < "$amneziaPath/server/$interfaceName.pool" > "$amneziaPath/server/$interfaceName.pool.temp"
mv -f "$amneziaPath/server/$interfaceName.pool.temp" "$amneziaPath/server/$interfaceName.pool"
logAction 005