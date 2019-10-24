#!/bin/ksh -x

CPUINF="/tmp/cpu"
MEMINF="/tmp/mem"
PARAMS="/tmp/SummaryUsage.txt"
HOSTNAME=`uname -n`
DATE=`date +'%e-%b-%Y %H:%M:%S'`


check_mem_linux ()
{
	MemTotal=`/bin/cat /proc/meminfo |grep -i mem|grep MemTotal|awk '{print $2}'`
	MemFree=`/bin/cat /proc/meminfo |grep -i mem|grep MemFree |awk '{print $2}'`
	MemUse=$(($MemTotal-$MemFree))
	MemUsePercent=`/bin/echo "scale=2; {($MemUse/$MemTotal)*100}" | bc | cut -d"." -f1`

	if [ $MemUsePercent -lt 1 ];then
        	MemUsePercent="1"
        fi
}

check_cpu_linux ()
{


	/usr/bin/vmstat 1 11 > $CPUINF
	totalcpu=`/bin/cat $CPUINF |tail -10| gawk '{ print sum += $15 }'|tail -1`
	CpuUsePercent=`/bin/echo "scale=2; {(1000-$totalcpu)/10}" | bc`

	if [ $CpuUsePercent -lt 1 ];then
        	CpuUsePercent="1"
        fi

}

check_network_transmit_linux ()
{


	Interface=`/bin/netstat -i|awk '{print $1,$4}'|grep -v Kernel|grep -v Iface |grep -v lo |awk '{print $1}'|head -1`

	if [ `echo $Interface | grep -i bond` -eq 0 ] ; then
		NewInterface=`grep $Interface /etc/sysconfig/network-scripts/ifcfg-eth* | awk -F: '{print $1}' | awk -F- '{print $NF}' | head -1`
		Interface=$NewInterface
	fi

	first=`cat /proc/net/dev |grep $Interface |awk '{print $9}' |awk -F: '{print $1}'`

	/bin/echo "PLEASE WAIT"
	sleep 20

	second=`cat /proc/net/dev |grep $Interface| awk '{print $9}' | awk -F: '{print $1}'`

	total_byte=$(($second-$first))
	bit_per_second=`/bin/echo "scale=2; {($total_byte*8/60)}" |bc -l`

	NetSpeed=`/sbin/ethtool $Interface |grep -i Speed|awk '{print $2}'|cut -d"M" -f1`

	mega_bit=`/bin/echo "scale=2; {($NetSpeed*1000000)}" |bc -l`
	NetUsePercentTransmit=`/bin/echo "scale=2; {($bit_per_second*100/$mega_bit)}" |bc -l`

	if [ $NetUsePercentTransmit -lt 1 ];then
		NetUsePercentTransmit="1"
	fi
}

check_network_receive_linux ()
{


        Interface=`/bin/netstat -i|awk '{print $1,$4}'|grep -v Kernel|grep -v Iface |grep -v lo |awk '{print $1}'|head -1`

	if [ `echo $Interface | grep -i bond` -eq 0 ] ; then
		NewInterface=`grep $Interface /etc/sysconfig/network-scripts/ifcfg-eth* | awk -F: '{print $1}' | awk -F- '{print $NF}' | head -1`
		Interface=$NewInterface
	fi

        first=`cat /proc/net/dev |grep $Interface| awk '{print $1}' | awk -F: '{print $2}'`

	/bin/echo "PLEASE WAIT"
        sleep 20

        second=`cat /proc/net/dev |grep $Interface| awk '{print $1}' | awk -F: '{print $2}'`

        total_byte=$(($second-$first))
        bit_per_second=`/bin/echo "scale=2; {($total_byte*8/60)}" |bc -l`

        NetSpeed=`/sbin/ethtool $Interface |grep -i Speed|awk '{print $2}'|cut -d"M" -f1`

        mega_bit=`/bin/echo "scale=2; {($NetSpeed*1000000)}" |bc -l`
        NetUsePercentReceive=`/bin/echo "scale=2; {($bit_per_second*100/$mega_bit)}" |bc -l`

        if [ $NetUsePercentReceive -lt 1 ];then
                NetUsePercentReceive="1"
        fi
}

summary_network_linux ()
{
	TotalUseNetPerdent=`/bin/echo "scale=2; {($NetUsePercentReceive+$NetUsePercentTransmit)}" |bc -l`
}



check_ip_linux ()
{

	Interface=`/bin/netstat -i|awk '{print $1,$4}'|grep -v Kernel|grep -v Iface |grep -v lo |awk '{print $1}'|head -1`
	IP=`ifconfig -a  $Interface |grep "inet addr"|awk '{print $2}'|cut -d":" -f2`

} 




check_mem_sunos ()
{

	/usr/local/bin/top > $MEMINF
        MemTotal=`/bin/cat $MEMINF |grep -i mem|awk '{print $2}'|cut -d"M" -f1`
        MemFree=`/bin/cat $MEMINF |grep -i mem|awk '{print $5}'|cut -d"M" -f1`
        MemUse=$(($MemTotal-$MemFree))
        MemUsePercent=`/bin/echo "scale=2; {($MemUse/$MemTotal)*100}" | bc | cut -d"." -f1`
	
	if [ $MemUsePercent -lt 1 ];then
                MemUsePercent="1"
        fi

}

check_cpu_sunos ()
{


        /usr/bin/vmstat 1 11 > $CPUINF
        totalcpu=`/bin/cat $CPUINF |tail -10| awk '{ print sum += $22 }'|tail -1`
        CpuUsePercent=`/bin/echo "scale=2; {(1000-$totalcpu)/10}" | bc`

	if [ $CpuUsePercent -lt 1 ];then
                CpuUsePercent="1"
        fi

}


check_network_transmit_sunos ()
{


	Interface1=`/bin/netstat -i|awk '{print $1,$4}'|grep -v lo|grep -v Name|awk '{print $1}'|head -1|sed 's/\(.*\)\(.\)/\1:\2/`
	Interface=`/bin/netstat -i|awk '{print $1,$4}'|grep -v lo|grep -v Name|awk '{print $1}'|head -1`

        first=`/usr/bin/kstat -p $Interface1:$Interface:obytes64|awk '{print $2}'`

        /bin/echo "PLEASE WAIT"
        sleep 20

        second=`/usr/bin/kstat -p $Interface1:$Interface:obytes64|awk '{print $2}'`

        total_byte=$(($second-$first))
        bit_per_second=`/bin/echo "scale=2; {($total_byte*8/60)}" |bc -l`

        NetSpeed=`/usr/bin/kstat -p $Interface1:$Interface:ifspeed|grep -i Speed|awk '{print $2}'`
        NetUsePercentTransmit=`/bin/echo "scale=2; {($bit_per_second*100/$NetSpeed)}" |bc -l`

        if [ $NetUsePercentTransmit -lt 1 ];then
                NetUsePercentTransmit="1"
        fi
}


check_network_receive_sunos ()
{

	Interface1=`/bin/netstat -i|awk '{print $1,$4}'|grep -v lo|grep -v Name|awk '{print $1}'|head -1|sed 's/\(.*\)\(.\)/\1:\2/`
        Interface=`/bin/netstat -i|awk '{print $1,$4}'|grep -v lo|grep -v Name|awk '{print $1}'|head -1`

        first=`/usr/bin/kstat -p $Interface1:$Interface:rbytes64|awk '{print $2}'`

        /bin/echo "PLEASE WAIT"
        sleep 20

        second=`/usr/bin/kstat -p $Interface1:$Interface:rbytes64|awk '{print $2}'`

        total_byte=$(($second-$first))
        bit_per_second=`/bin/echo "scale=2; {($total_byte*8/60)}" |bc -l`

        NetSpeed=`/usr/bin/kstat -p $Interface1:$Interface:ifspeed|grep -v mac|grep -i Speed|awk '{print $2}'`
        NetUsePercentReceive=`/bin/echo "scale=2; {($bit_per_second*100/$NetSpeed)}" |bc -l`

        if [ $NetUsePercentReceive -lt 1 ];then
                NetUsePercentReceive="1"
        fi
}

summary_network_sunos ()
{
        TotalUseNetPerdent=`/bin/echo "scale=2; {($NetUsePercentReceive+$NetUsePercentTransmit)}" |bc -l`
}

check_ip_sunos ()
{
        Interface=`/bin/netstat -i|awk '{print $1,$4}'|grep -v Name|grep -v lo |awk '{print $1}'|head -1`
        IP=`ifconfig $Interface |grep inet|awk '{print $2}'|cut -d":" -f2`
}


print_total ()
{
	#print_line
	/bin/echo "$DATE,$HOSTNAME,$IP,$MemUsePercent,$CpuUsePercent,$TotalUseNetPerdent" >> $PARAMS	
}

### Main ####

OS=`uname`
if [ "X$OS" == "XLinux" ];then
	check_mem_linux
	check_cpu_linux
	check_network_transmit_linux
	check_network_receive_linux
	summary_network_linux
	check_ip_linux

else
	check_mem_sunos
	check_cpu_sunos
	check_network_transmit_sunos
	check_network_receive_sunos
	summary_network_sunos
	check_ip_sunos
fi
print_total
