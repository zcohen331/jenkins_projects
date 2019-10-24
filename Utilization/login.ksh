#!/bin/ksh


user=root
protocol_ssh=ssh
protocol_scp=scp

for ipaddr in `cat updateip.txt`;do

	for pass in `cat password.txt`;do

		/Utilization/copy_script.exp $ipaddr $user $pass scp

		if [ $? -eq 0 ];then
		
			/Utilization/connect.exp $ipaddr $user $pass ssh
			/Utilization/get_sum.exp $ipaddr $user $pass scp
		fi
	done
done
