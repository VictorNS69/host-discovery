#! /bin/bash

# $1 format -> x.x.x.x/yy
# TODO: check if the imput follows the expected format "x.x.x.x/yy"
# TODO: add "output dir" feature

# Just some colors
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)


# Checking imput exists
if [ "$#" -ne 1 ]
  then
  echo "Please provide only one argument"
  echo "Example usage: sudo ./host_scan.sh 192.168.0.0/24"
  exit 1
fi

# Checking if root (some issues depend on tool instalation, so using root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi


printf "${GREEN}Target: $1 ${NORMAL}"

# Transform IP/mask to all IPs in the range
IP_LIST=$(nmap -sL -n $1 | awk '/Nmap scan report/{print $NF}')

printf "${YELLOW}Doing ping3 scan. This may take some time ${NORMAL}"
for i in $IP_LIST ; do sudo ping3 -c 1 $i | grep -v "Timeout" > ping3_sweep.txt ; done

cat ping3_sweep.txt | awk -F[\'] '{print $2}' > live_hosts.txt
printf "${GREEN}Live hosts found! -> $PWD/live_hosts.txt ${NORMAL}"

printf "${YELLOW}Doing fast nmap scan (only a few ports). This may take some time ${NORMAL}"
sudo nmap -Ss -Pn -p 21-23,80,443,445,8080,8443 -o nmap_fast_scan.txt -iL live_hosts.txt
printf "${GREEN}Nmap fast scan done! -> $PWD/nmap_fast_scan.txt ${NORMAL}"

printf "${YELLOW}Doing full nmap scan. This may take some time $1 ${NORMAL}"
sudo nmap -Pn -A -o nmap_full_scan.txt -iL live_hosts.txt
printf "${GREEN}Nmap full scan done! -> $PWD/nmap_full_scan.txt ${NORMAL}"

printf "${GREEN}Script complete! Happy hunting! ${NORMAL}"

exit 