#!/bin/bash

printf "\e[93m==== awg-add-peer by CrPO4 ====\e[0m\n"

if [ "$1" == "--help" ]; then 
    printf "Interactive mode: run without parameters.\n";
    printf "Inline mode: ./awg-add-peer.sh /path/to/amnezia interfaceName peerName\n";
    exit 0;
fi

if [ "$#" -ne 0 ] && [ "$#" -ne 4 ]; then
  echo "Error: This script requires either 0 or 4 non-empty arguments.";
  exit 1;
fi

declare logFile
logFile=$(pwd)/awg-add-peer.log

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
declare serverEndpointAddress
if [ -n "$4" ]; then 
    serverEndpointAddress="$4"; 
else
    serverEndpointAddress=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    printf "            Endpoint address [%s]: " "$serverEndpointAddress"; read -r tempServerEndpointAddress
    if [ -n "$tempServerEndpointAddress" ]; then serverEndpointAddress="$tempServerEndpointAddress"; fi
fi
logAction 003
announceAction 004 "Creating client keys"
"$amneziaPath"/binaries/awg genkey | tee "$amneziaPath"/clients/"$interfaceName"-"$peerName".key | "$amneziaPath"/binaries/awg pubkey | tee "$amneziaPath"/clients/"$interfaceName"-"$peerName".key.pub &>/dev/null
logAction 004
announceAction 004 "Preparing variables for peer"
declare serverPublicKey
serverPublicKey=$(<"$amneziaPath"/server/"$interfaceName"_public.key)

mapfile -t interfaceVariables < "$amneziaPath"/server/"$interfaceName".variables
declare ipWithPort
ipWithPort="$serverEndpointAddress":"${interfaceVariables[0]}"
declare peerPublicKey
declare peerPrivateKey
peerPublicKey=$(<"$amneziaPath"/clients/"$interfaceName"-"$peerName".key.pub)
peerPrivateKey=$(<"$amneziaPath"/clients/"$interfaceName"-"$peerName".key)
declare privateFirstOctet
declare privateSecondOctet
declare privateThirdOctet
declare nextPoolAddress
privateFirstOctet=${interfaceVariables[1]}
privateSecondOctet=${interfaceVariables[2]}
privateThirdOctet=${interfaceVariables[3]}
nextPoolAddress=$(tail -1 "$amneziaPath"/server/"$interfaceName".pool)
if [ "$nextPoolAddress" -gt 254 ]; then
    printf "All available addresses seem to be taken as indicated by %s. Remove unused clients or setup additional interface with different IP range.\n" "$amneziaPath/server/$interfaceName.pool";
    exit 1;
fi
resultingAddress=$(echo "$privateFirstOctet"."$privateSecondOctet"."$privateThirdOctet"."$nextPoolAddress" | tr -d '\n')
logAction 004
announceAction 005 "Creating peer profile"
touch "$amneziaPath"/clients/"$interfaceName"-"$peerName".conf
echo "[Interface]
PrivateKey = $peerPrivateKey
Address = $resultingAddress
DNS = 1.1.1.1, 8.8.8.8
Jc = ${interfaceVariables[4]}
Jmin = ${interfaceVariables[5]}
Jmax = ${interfaceVariables[6]}
S1 = ${interfaceVariables[7]}
S2 = ${interfaceVariables[8]}
H1 = ${interfaceVariables[9]}
H2 = ${interfaceVariables[10]}
H3 = ${interfaceVariables[11]}
H4 = ${interfaceVariables[12]}

[Peer]
PublicKey = $serverPublicKey
Endpoint = $ipWithPort
AllowedIPs = 0.0.0.0/5, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/2, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/6, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/10, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4" >"$amneziaPath"/clients/"$interfaceName"-"$peerName".conf
logAction 005
announceAction 006 "Adding peer profile to interface configuration"
echo "
[Peer]
### $peerName
PublicKey = $peerPublicKey
AllowedIPs = $resultingAddress" >> "$amneziaPath"/server/"$interfaceName".conf
logAction 006
announceAction 007 "Reloading interface to apply new settings"
systemctl reload awg-quick@"$interfaceName".service
logAction 007
announceAction 008 "Printing configuration to Terminal"
printf "\e[93m================================================================================\e[0m\n"
cat "$amneziaPath"/clients/"$interfaceName"-"$peerName".conf
printf "\e[93m================================================================================\e[0m\n"
logAction 007
announceAction 008 "Updating IP pool"
head -n-1 "$amneziaPath/server/$interfaceName.pool" > "$amneziaPath/server/$interfaceName.pool.temp"
mv -f "$amneziaPath/server/$interfaceName.pool.temp" "$amneziaPath/server/$interfaceName.pool"
logAction 008