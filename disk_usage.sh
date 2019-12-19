#!/bin/bash

echo "------------Server details---------"
echo "1. Server ip : " `ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
echo "2. Hostname : " `hostname`
echo "3. OS information : " `cat /etc/redhat-release` `cat /etc/issue`
echo "4. Total virtual CPU : " `nproc` 
echo "5. Total Memory in GB : "`free -h | awk '/Mem\:/ { print $2 }'` 


BLOCKS=0

# The special /sys/ folder contains device information, not actual files.

DISK=`ls -l  /sys/class/block/sd*`
diskopt=$?
if [[ diskopt -eq 0 ]]
then
for DEV in /sys/class/block/sd*
do
        [[ -f "$DEV/start" ]] && continue       # Skip partitions
        read B < $DEV/size                      # Read num of blocks
        read MODEL < $DEV/device/model          # Read model

       # printf "%-40s%15d blocks %5d GB\n" "$MODEL" "$B" $((B/(1024*1024*2) ))
        ((BLOCKS+=B))   # Add to total
done

else
DISK=`ls -l /sys/class/block/xvd*`
diskopt=$?
for DEV in /sys/class/block/xvd*
do
        [[ -f "$DEV/start" ]] && continue       # Skip partitions
        read B < $DEV/size                      # Read num of blocks
        read MODEL < $DEV/device/model          # Read model

        printf "%-40s%15d blocks %5d GB\n" "$MODEL" "$B" $((B/(1024*1024*2) ))
        ((BLOCKS+=B))   # Add to total
done

fi

#printf "%-40s%15d blocks %5d GB\n" "total" "$BLOCKS" $((BLOCKS/(1024*1024*2)))

ANS=$((BLOCKS/(1024*1024*2)))

echo "6. Total Disk storage in GB : $ANS GB " 

echo "7. Total Swap memory in GB : " `free -h | grep Swap | awk '{ print $2 }'`

