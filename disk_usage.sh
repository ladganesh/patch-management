#!/bin/bash

BLOCKS=0

# The special /sys/ folder contains device information, not actual files.

DISK=`ls -l  /sys/class/block/sd*`
diskopt=$?
#if [ diskopt == 0 ]
if [[ diskopt -eq 0 ]]
then
for DEV in /sys/class/block/sd*
do
        [[ -f "$DEV/start" ]] && continue       # Skip partitions
        read B < $DEV/size                      # Read num of blocks
        read MODEL < $DEV/device/model          # Read model

        printf "%-40s%15d blocks %5d GB\n" "$MODEL" "$B" $((B/(1024*1024*2) ))
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
#else
#       echo "Please check HDD"

fi

printf "%-40s%15d blocks %5d GB\n" "total" "$BLOCKS" $((BLOCKS/(1024*1024*2)))

#ANS = (BLOCKS/(1024*1024*2))
ANS=$((BLOCKS/(1024*1024*2)))


echo -e "\n\n TOTAL=$ANS GB"
