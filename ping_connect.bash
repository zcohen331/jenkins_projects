#!/bin/bash

for ipaddr in `cat /home/terra/expect/listip.txt`;do

ping -c 1 $ipaddr 1>/dev/null

if [ $? -ne 0 ]; then

echo "This $ipaddr unreachable"
exit

fi

done
