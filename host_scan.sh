#! /bin/bash

# $1 format -> x.x.x.x/yy where yy = [0..32]

# Just some colors
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)

#################
### FUNCTIONS ###
#################

Banner (){
  echo "
                   _                          
 |_|  _   _ _|_   | \ o  _  _  _      _  ._   
 | | (_) _>  |_   |_/ | _> (_ (_) \/ (/_ | \/ 
                                           /                                                              
"                                                       
}

CheckArguments (){
  # Checking if input exists
  # $1 is the number of arguments ($#)
  if [ "$1" -ne 2 ]
    then
    echo "Please provide only two arguments. IP/Mask range and output directory"
    echo "Example usage: sudo ./host_scan.sh 192.168.0.0/24 /tmp/discovery"
    exit 1
  fi
}

CheckDir (){
  # Checking output directory
  # $1 is the directory
  if [[ ! -d "$1" ]]
    then
    echo "The directory \"$1\" does not exist"
    mkdir -p "$1"
    if [ $? -ne 0 ]
      then
      echo "Error creating "$1" directory"
      echo "Exiting"
      exit 1
    else
      echo "Directory "$1" created"
    fi
  elif [[ ! -w "$1" ]]
    then
    echo "You have no write access in "$1""
    echo "Exiting"
    exit 1
  else
    echo "Directory "$1" exists"
  fi
}

CheckValidIpMask (){
  # Checking if valid IP/mask
  # $1 is the IP/mask range
  n='([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])'
  m='([0-9]|[12][0-9]|3[012])'
  if [[ $1 =~ ^$n(\.$n){3}/$m$ ]]
    then
    printf "${GREEN}Target: $1 ${NORMAL}\n"
  else
    printf "$1 does not follow the expected expression x.x.x.x/[0-32] or is not a valid range \n"
    echo "Exiting"
    exit 1
  fi
}
CheckRoot (){
  # Checking if root (some issues depend on tool instalation, so using root)
  if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    echo "Exiting"
    exit 1
  fi
}

Ping3Discovery (){
  # Ping discovery
  printf "${YELLOW}Doing ping3 scan. This may take some time ${NORMAL}\n"
  for ip in $IP_LIST
  do
    sudo ping3 -c 1 $ip | grep -v "Timeout" | tee -a "$OUTPUT_DIR/ping3_sweep.txt"
  done
}

FastNmap (){
  # Fast nmap scan web ports and few more
  printf "${YELLOW}Doing fast nmap scan (only a few ports). This may take some time ${NORMAL}\n"
  sudo nmap -sS -Pn -p 21-23,80,443,445,8000,8080,8443 -T5 -o "$OUTPUT_DIR/nmap_fast_scan.txt" -iL "$OUTPUT_DIR/live_hosts.txt" --stats-every 1m
  printf "${GREEN}Nmap fast scan done! -> \"$OUTPUT_DIR/nmap_fast_scan.txt\" ${NORMAL}\n"
}

FullNmap (){
  # Nmap -A
  printf "${YELLOW}Doing full nmap scan. This may take some time ${NORMAL}\n"
  for ip in $(cat "$OUTPUT_DIR/live_hosts.txt")
  do
    sudo nmap -Pn -A -o "$OUTPUT_DIR/nmap_full_scan_${ip}.txt" --stats-every 1m ${ip}
    printf "${GREEN}Nmap full scan for ${ip} done! -> \"$OUTPUT_DIR/nmap_full_scan_${ip}.txt\" ${NORMAL}\n"
  done
}

##################
###### MAIN ######
##################

Banner 

# Checks
CheckArguments $#
CheckValidIpMask $1
OUTPUT_DIR=$(readlink -f "$2")
CheckDir $OUTPUT_DIR
CheckRoot
  
# Transform IP/mask to all IPs in the range
IP_LIST=$(nmap -sL -n $1 | awk '/Nmap scan report/{print $NF}')
  
Ping3Discovery
  
cat "$OUTPUT_DIR/ping3_sweep.txt" | awk -F[\'] '{print $2}' > "$OUTPUT_DIR/live_hosts.txt"
TOTAL_HOSTS=$(wc -l "$OUTPUT_DIR/live_hosts.txt" | awk '{print $1}')
if [[ $TOTAL_HOSTS -eq 0 ]]
then
 printf "${GREEN}No live hosts found${NORMAL}\n"
 #echo "Removing output directory (it is empty)"
 #rm -rf "$OUTPUT_DIR"
 echo "Exiting"
 exit 0
fi 
printf "${GREEN}$TOTAL_HOSTS live hosts found! -> \"$OUTPUT_DIR/live_hosts.txt\" ${NORMAL}\n"
  
FastNmap
 
FullNmap
printf "${GREEN}Script complete! Happy hunting! ${NORMAL}\n"
exit 0
