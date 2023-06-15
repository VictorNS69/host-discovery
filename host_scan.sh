#! /bin/bash

# $1 format -> x.x.x.x/yy
# TODO: check if the input follows the expected format "x.x.x.x/yy"

# Just some colors
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)


# Checking if input exists
if [ "$#" -ne 2 ]
  then
  echo "Please provide only two arguments"
  echo "Example usage: sudo ./host_scan.sh 192.168.0.0/24 /tmp/discovery"
  exit 1
fi

# Checking output directory (2nd argument)
OUTPUT_DIR="$(readlink -f "$2")"
if [[ ! -d "$OUTPUT_DIR" ]]
  then
  echo "The directory \"$OUTPUT_DIR\" does not exist"
  mkdir -p "$OUTPUT_DIR"
  if [ $? -ne 0 ]
    then
    echo "Error creating "$OUTPUT_DIR" directory"
    echo "Exiting"
    exit 1
  else
    echo "Directory "$OUTPUT_DIR" created"
  fi
elif [[ ! -w "$OUTPUT_DIR" ]]
  then
  echo "You have no write access in "$OUTPUT_DIR""
  exit 1
else
  echo "Directory "$OUTPUT_DIR" exists"
fi

# Checking if root (some issues depend on tool instalation, so using root)
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi


printf "${GREEN}Target: $1 ${NORMAL}\n"

# Transform IP/mask to all IPs in the range
IP_LIST=$(nmap -sL -n $1 | awk '/Nmap scan report/{print $NF}')

printf "${YELLOW}Doing ping3 scan. This may take some time ${NORMAL}\n"
for ip in $IP_LIST
do
  sudo ping3 -c 1 $ip | grep -v "Timeout" | tee -a "$OUTPUT_DIR/ping3_sweep.txt"
done

cat "$OUTPUT_DIR/ping3_sweep.txt" | awk -F[\'] '{print $2}' > "$OUTPUT_DIR/live_hosts.txt"
TOTAL_HOSTS=$(wc -l "$OUTPUT_DIR/live_hosts.txt" | awk '{print $1}')
printf "${GREEN}$TOTAL_HOSTS live hosts found! -> \"$OUTPUT_DIR/live_hosts.txt\" ${NORMAL}\n"

printf "${YELLOW}Doing fast nmap scan (only a few ports). This may take some time ${NORMAL}\n"
sudo nmap -sS -Pn -p 21-23,80,443,445,8080,8443 -T5 -o "$OUTPUT_DIR/nmap_fast_scan.txt" -iL "$OUTPUT_DIR/live_hosts.txt" --stats-every 1m
printf "${GREEN}Nmap fast scan done! -> \"$OUTPUT_DIR/nmap_fast_scan.txt\" ${NORMAL}\n"

printf "${YELLOW}Doing full nmap scan. This may take some time ${NORMAL}\n"
for ip in $(cat "$OUTPUT_DIR/live_hosts.txt")
do
  sudo nmap -Pn -A -o "$OUTPUT_DIR/nmap_full_scan_${ip}.txt" --stats-every 1m ${ip}
  printf "${GREEN}Nmap full scan for ${ip} done! -> \"$OUTPUT_DIR/nmap_full_scan_${ip}.txt\" ${NORMAL}\n"
done

printf "${GREEN}Script complete! Happy hunting! ${NORMAL}\n"

exit 0
