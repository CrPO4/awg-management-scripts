#!/bin/bash

declare logFile
logFile=$(pwd)/awg-server-setup.log

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

printf "\e[93m==== awg-install by CrPO4 ====\e[0m\n"
printf "            Make sure that you have run \"apt update\" and \"apt upgrade\" before running this script [yes\NO]: "; read -r aptConfirmed
if [ "$aptConfirmed" != "yes" ]; then printf "You have to type lowercase yes in order to confirm. Exiting"; exit 1; fi
announceAction 001 "Making log file"
touch "$logFile"
declare buildDir
buildDir=$(pwd)/amnezia-project
logAction 001 "Warning 001: From now on, almost all output will be made to $logFile."
announceAction 002 "Setting terminal to non-interactive mode"
export DEBIAN_FRONTEND=noninteractive
logAction 002
announceAction 003 "Updating APT state"
apt --yes update &>>"$logFile"
logAction 003
announceAction 004 "Upgrading OS"
apt --yes dist-upgrade &>>"$logFile"
logAction 004
announceAction 005 "Installing prerequisites"
apt --yes install make gcc git &>>"$logFile"
logAction 005
announceAction 006 "Making build directory"
mkdir --parents "$buildDir" &>>"$logFile"
logAction 006
announceAction 007 "Switching to build directory"
cd "$buildDir" &>>"$logFile" || exit 1
logAction 007
announceAction 008 "Getting information about latest Go version"
declare LATEST_GO
LATEST_GO=$(curl -s https://go.dev/VERSION?m=text | head -1) &>>"$logFile"
logAction 008
announceAction 009 "Downloading latest Go version"
wget "https://dl.google.com/go/$LATEST_GO.linux-amd64.tar.gz" &>>"$logFile"
logAction 009
announceAction 010 "Unpacking latest Go version to /usr/local"
tar -C /usr/local -xzf "$LATEST_GO.linux-amd64.tar.gz" &>>"$logFile"
logAction 010
announceAction 011 "Adding Go version to PATH"
export PATH=$PATH:/usr/local/go/bin &>>"$logFile"
logAction 011
announceAction 012 "Cloning amneziawg-go Github repo"
git clone https://github.com/amnezia-vpn/amneziawg-go &>>"$logFile"
logAction 012
announceAction 013 "Switching to cloned repo directory"
cd amneziawg-go &>>"$logFile" || exit 1
logAction 013
announceAction 014 "Building amnezia-go"
make &>>"$logFile"
logAction 014
announceAction 015 "Returning to build directory"
cd "$buildDir" &>>"$logFile" || exit
logAction 015
announceAction 016 "Cloning amneziawg-tools Github repo"
git clone https://github.com/amnezia-vpn/amneziawg-tools &>>"$logFile"
logAction 016
announceAction 017 "Switching to cloned repo directory"
cd amneziawg-tools/src &>>"$logFile" || exit
logAction 017
announceAction 018 "Making adjustemnts to source code of amneziawg-tools"
declare amneziaPath
amneziaPath="/opt/amnezia"
printf "            Path to Amnezia configuration files [%s]: " "$amneziaPath"; read -r tempAmneziaPath
if [ -n "$tempAmneziaPath" ]; then amneziaPath="$tempAmneziaPath"; fi
sed -i "s#/etc/amnezia/amneziawg /usr/local/etc/amnezia/amneziawg#$amneziaPath/server#" ./wg-quick/darwin.bash
sed -i "s#/etc/amnezia/amneziawg/\$CONFIG_FILE.conf#$amneziaPath/server/\$CONFIG_FILE.conf#" ./wg-quick/linux.bash
sed -i "s#/etc/amnezia/amneziawg /usr/local/etc/amnezia/amneziawg#$amneziaPath/server#" ./wg-quick/freebsd.bash
sed -i "s#%{_sysconfdir}/amnezia/amneziawg/#$amneziaPath/server#" ../amneziawg-tools.spec
sed -i "s#non-standard-dir-perm etc/amneziawg/#non-standard-dir-perm $amneziaPath/#" ../debian/amneziawg-tools.lintian-overrides
sed -i "s#\$(DESTDIR)\/\$(SYSCONFDIR)/amnezia/amneziawg#\$amneziaPath/server#" Makefile
sed -i "s#/usr/bin/awg-quick#$amneziaPath/binaries/awg-quick#g" ./systemd/wg-quick@.service
sed -i "s#/usr/bin/awg#$amneziaPath/binaries/awg#g" ./systemd/wg-quick@.service
sed -i "s#WireGuard via wg-quick(8)#AmneziaWG via awg-quick#g" ./systemd/wg-quick@.service
sed -i "s#WireGuard Tunnels via wg-quick(8)#AmneziaWG Tunnels via awg-quick#g" ./systemd/wg-quick.target
logAction 018
announceAction 019 "Building amneziawg-tools"
make &>>"$logFile"
logAction 019
announceAction 020 "Returning to build directory"
cd "$buildDir" &>>"$logFile" || exit
logAction 020
announceAction 021 "Creating AmneziaWG directories"
{ mkdir --parents "$amneziaPath"/server;
mkdir --parents "$amneziaPath"/clients;
mkdir --parents "$amneziaPath"/binaries; } &>>"$logFile"
logAction 021
announceAction 022 "Installing compiled software"
{ cp -f ./amneziawg-go/amneziawg-go "$amneziaPath"/binaries/awg-go;
cp -f ./amneziawg-tools/src/wg "$amneziaPath"/binaries/awg;
cp -f ./amneziawg-tools/src/wg-quick/linux.bash "$amneziaPath"/binaries/awg-quick;
cp -f ./amneziawg-tools/src/man/wg.8 /usr/share/man/man8/awg.8;
cp -f ./amneziawg-tools/src/completion/wg.bash-completion /usr/share/bash-completion/completions/awg;
cp -f ./amneziawg-tools/src/man/wg-quick.8 /usr/share/man/man8/awg-quick.8;
cp -f ./amneziawg-tools/src/completion/wg-quick.bash-completion /usr/share/bash-completion/completions/awg-quick;
cp -f ./amneziawg-tools/src/systemd/wg-quick.target /lib/systemd/system/awg-quick.target;
cp -f ./amneziawg-tools/src/systemd/wg-quick@.service /lib/systemd/system/awg-quick@.service; } &>>"$logFile"
logAction 022
announceAction 023 "Making changes to awg-quick to support amnezia-go"
sed -i "s#ip link add \"\$INTERFACE\" type amneziawg#$amneziaPath/binaries/awg-go \"\$INTERFACE\"#" "$amneziaPath"/binaries/awg-quick &>>"$logFile"
logAction 023
announceAction 024 "Making systemd re-read daemons from disk"
systemctl daemon-reload &>>"$logFile"
logAction 024
announceAction 025 "Getting required user data"
declare serverIpAddress
serverIpAddress="192.168.150.1"
printf "            Server INTERNAL IP address [%s]: " "$serverIpAddress"; read -r tempServerIpAddress
if [ -n "$tempServerIpAddress" ]; then serverIpAddress="$tempServerIpAddress"; fi
declare serverPort
serverPort="44770"
printf "            Listening port [%s]: " "$serverPort"; read -r tempServerPort
if [ -n "$tempServerPort" ]; then serverPort="$tempServerPort"; fi
declare sshPort
sshPort="22"
printf "            SSH port [%s]: " "$sshPort"; read -r tempSshPort
if [ -n "$tempSshPort" ]; then sshPort="$tempSshPort"; fi
declare interfaceName
interfaceName="awg0"
printf "            Interface name [%s]: " "$interfaceName"; read -r tempInterfaceName
if [ -n "$tempInterfaceName" ]; then interfaceName="$tempInterfaceName"; fi
declare randomJc
randomJc=$(shuf -i 2-20 -n 1)
declare randomJmin
randomJmin=$(shuf -i 30-70 -n 1)
declare randomJmax
randomJmax=$(shuf -i 750-1250 -n 1)
declare randomS1
randomS1=$(shuf -i 50-150 -n 1)
declare randomS2
randomS2=$(shuf -i 20-100 -n 1)
declare randomH1
randomH1=$(shuf -i 400000000-499999999 -n 1)
declare randomH2
randomH2=$(shuf -i 300000000-399999999 -n 1)
declare randomH3
randomH3=$(shuf -i 200000000-299999999 -n 1)
declare randomH4
randomH4=$(shuf -i 100000000-199999999 -n 1)
logAction 025
announceAction 026 "Generating AmneziaWG private key"
"$amneziaPath"/binaries/awg genkey | tee "$amneziaPath"/server/"$interfaceName"_private.key &>>"$logFile"
logAction 026
announceAction 027 "Setting AmneziaWG private key permissions"
chmod go= "$amneziaPath"/server/"$interfaceName"_private.key &>>"$logFile"
logAction 027
announceAction 028 "Generating AmneziaWG public key"
"$amneziaPath"/binaries/awg pubkey < "$amneziaPath"/server/"$interfaceName"_private.key | tee "$amneziaPath"/server/"$interfaceName"_public.key &>>"$logFile"
logAction 028
announceAction 029 "Assigning variables"
declare serverPrivateKey
serverPrivateKey=$(<"$amneziaPath"/server/"$interfaceName"_private.key) &>>"$logFile"
declare networkDevice
networkDevice=$(ip route get 8.8.8.8 | awk -F"dev " 'NR==1{split($2,a," ");print a[1]}') &>>"$logFile"
logAction 029
announceAction 030 "Creating server configuration"
touch "$amneziaPath"/server/"$interfaceName".conf
echo "[Interface]
PrivateKey = $serverPrivateKey
Address = $serverIpAddress
ListenPort = $serverPort
SaveConfig = false
Jc = $randomJc
Jmin = $randomJmin
Jmax = $randomJmax
S1 = $randomS1
S2 = $randomS2
H1 = $randomH1
H2 = $randomH2
H3 = $randomH3
H4 = $randomH4
PostUp = ufw route allow in on $interfaceName out on $networkDevice
PostUp = iptables -t nat -I POSTROUTING -o $networkDevice -j MASQUERADE
PreDown = ufw route delete allow in on $interfaceName out on $networkDevice
PreDown = iptables -t nat -D POSTROUTING -o $networkDevice -j MASQUERADE" > "$amneziaPath"/server/"$interfaceName".conf
logAction 030
announceAction 031 "Changing network stack settings"
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
logAction 031
announceAction 032 "Applying network stack settings"
sysctl -p &>>"$logFile"
logAction 032
announceAction 033 "Adding firewall rules"
{ ufw allow "$serverPort"/udp;
ufw allow "$sshPort"/tcp; } &>>"$logFile"
ufw reload &>>"$logFile"
logAction 033
announceAction 034 "Starting AmneziaWG"
systemctl enable awg-quick@"$interfaceName".service --now &>>"$logFile"
logAction 034
announceAction 035 "Saving variables for later use"
touch "$amneziaPath"/server/"$interfaceName".variables
declare privateFirstOctet
declare privateSecondOctet
declare privateThirdOctet
privateFirstOctet=$(echo "$serverIpAddress" | awk -F '.' '{print $1}')
privateSecondOctet=$(echo "$serverIpAddress" | awk -F '.' '{print $2}')
privateThirdOctet=$(echo "$serverIpAddress" | awk -F '.' '{print $3}')
echo "$serverPort
$privateFirstOctet
$privateSecondOctet
$privateThirdOctet
$randomJc
$randomJmin
$randomJmax
$randomS1
$randomS2
$randomH1
$randomH2
$randomH3
$randomH4" > "$amneziaPath"/server/"$interfaceName".variables
logAction 035
announceAction 036 "Initiating IP pool"
declare address
address=255;
while [ "$address" -ge 2 ]; do 
   echo "$address" >> "$amneziaPath"/server/"$interfaceName".pool; 
   address=$((address - 1)); 
done
logAction 036
announceAction 037 "Removing leftovers"
rm -rf amnezia-project
rm -rf go
rm -rf awg-server-setup.log
logAction 037
announceAction 038 "Printing removal help to Terminal"
printf "In case you ever need to COMPLETELY remove EVERYTHING related to AmneziaWG\n"
printf "from this server, you will need to execute the following commands:\n"
printf "================================================================================\n"
printf "for interface in \$(systemctl | grep \"AmneziaWG\ via\ awg-quick\" | awk '{print \$1}'); do systemctl disable "\$interface" --now; done\n" 
printf "rm -rf %s\n" "$amneziaPath"
printf "rm -f /usr/share/man/man8/awg.8\n"
printf "rm -f /usr/share/bash-completion/completions/awg\n"
printf "rm -f /usr/share/man/man8/awg-quick.8\n"
printf "rm -f /usr/share/bash-completion/completions/awg-quick\n"
printf "rm -f /lib/systemd/system/awg-quick.target\n"
printf "rm -f /lib/systemd/system/awg-quick@.service\n"
printf "================================================================================\n"
printf "These commands won't ever be shown again (unless you try to run another installation or read the script itself). Write them down.\n"
