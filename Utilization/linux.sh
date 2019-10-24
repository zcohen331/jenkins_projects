#!/bin/sh

# Simple script to obtain host info from Linux systems
# Script is divided into sections to match discovery methods

os=`uname -s`
if [ "$os" != "Linux" ]; then
    echo This script must be run on Linux
    exit 1
fi

# Set PATH
PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PATH

# Initialisation
tw_locale=`locale -a | grep -i en_us | grep -i "utf.*8" | head -n 1 2>/dev/null`

LANGUAGE=""
if [ "$tw_locale" != "" ]; then
    LANG=$tw_locale
    LC_ALL=$tw_locale
else
    LANG=C
    LC_ALL=C
fi
export LANG LC_ALL


# insulate against systems with -u set by default
set +u

if [ -w /tmp ] 
then
    # use a /tmp file to capture stderr
    TW_CAPTURE_FILE=/tmp/tideway_status_$$
    export TW_CAPTURE_FILE
    rm -f $TW_CAPTURE_FILE

    tw_capture(){
        TW_NAME=$1
        shift
        echo begin cmd_status_err_$TW_NAME >>$TW_CAPTURE_FILE
        "$@" 2>>$TW_CAPTURE_FILE
        RETURN_VAL=$?
        echo end cmd_status_err_$TW_NAME >>$TW_CAPTURE_FILE

        echo cmd_status_$TW_NAME=$RETURN_VAL >>$TW_CAPTURE_FILE
        return $RETURN_VAL
    }

    tw_report(){
        if [ -f $TW_CAPTURE_FILE ]
        then 
            cat $TW_CAPTURE_FILE 2>/dev/null
            rm -f $TW_CAPTURE_FILE 2>/dev/null
        fi
    }
else
    # can't write to /tmp - do not capture anything
    tw_capture(){
        shift
        "$@" 2>/dev/null
    }

    tw_report(){
        echo "cmd_status_err_status_unavailable=Unable to write to /tmp"
    }
fi 

# replace the following PRIV_XXX functions with one that has the path to a
# program to run the commands as super user, e.g. sudo. For example
# PRIV_LSOF() {
#   /usr/bin/sudo "$@"
# }

# lsof requires superuser privileges to display information on processes
# other than those running as the current user
PRIV_LSOF() {
  "$@"
}

# This function supports running privileged commands from patterns
PRIV_RUNCMD() {
  "$@"
}

# dmidecode requires superuser privileges to read data from the system BIOS
PRIV_DMIDECODE() {
    "$@"
}

# hwinfo requires superuser privileges to read data from the system BIOS
PRIV_HWINFO() {
    "$@"
}

# mii-tool requires superuser privileges to display any interface speed
# and negotiation settings
PRIV_MIITOOL() {
    "$@"
}

# ethtool requires superuser privileges to display any interface speed
# and negotiation settings
PRIV_ETHTOOL() {
    "$@"
}

# netstat requires superuser privileges to display process identifiers (PIDs)
# for ports opened by processes not running as the current user
PRIV_NETSTAT() {
    "$@"
}

# lputil requires superuser privileges to display any HBA information
PRIV_LPUTIL() {
    "$@"
}

# hbacmd requires superuser privileges to display any HBA information
PRIV_HBACMD() {
    "$@"
}

# emlxadm requires superuser privileges to display any HBA information
PRIV_EMLXADM() {
    "$@"
}

# Xen's xe command requires superuser privileges
PRIV_XE(){
    "$@"
}

# esxcfg-info command requires superuser privileges
PRIV_ESXCFG(){
    "$@"
}

# Formatting directive
echo FORMAT Linux

# getDeviceInfo
echo --- START device_info
ihn=`hostname 2>/dev/null | cut -f1 -d.`
if [ "$ihn" = "localhost" ]; then
    ihn=`hostname 2>/dev/null`
fi
echo 'hostname:' $ihn
echo 'fqdn:' `hostname --fqdn 2>/dev/null`
dns_domain=`hostname -d 2>/dev/null | sed -e 's/(none)//'` 
if [ "$dns_domain" = "" -a -f /etc/resolv.conf ]; then 
  dns_domain=`awk '/^(domain|search)/ {sub(/\\\\000$/, "", $2); print $2; exit }' /etc/resolv.conf 2>/dev/null` 
fi 
echo 'dns_domain: ' $dns_domain
echo 'domain:' `hostname -y 2>/dev/null | sed -e 's/(none)//'`
os=""

if [ "$os" = "" -a -e /proc/vmware/version ]; then
    os=`grep -m1 ESX /proc/vmware/version`
fi
if [ "$os" = "" -a -x /usr/bin/vmware ]; then
    os=`/usr/bin/vmware -v 2>/dev/null | grep ESX`
fi
if [ "$os" = "" -a -f /etc/vmware-release ]; then
    os=`grep ESX /etc/vmware-release`
fi
if [ "$os" = "" -a -f /etc/redhat-release ]; then
    os=`cat /etc/redhat-release`

    # Check to see if its a variant of Red Hat
    rpm -q oracle-logos > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        # Oracle variant
        os="Oracle $os"
    fi
fi
if [ "$os" = "" -a -f /etc/SuSE-release ]; then
    os=`head -n 1 /etc/SuSE-release`
fi
if [ "$os" = "" -a -f /etc/lsb-release ]; then
    ostype=`grep DISTRIB_ID /etc/lsb-release | cut -f2 -d=`
    osver=`grep DISTRIB_RELEASE /etc/lsb-release | cut -f2 -d=`
    os="$ostype $osver"
fi
if [ "$os" = "" -a -f /etc/debian_version ]; then
    ver=`cat /etc/debian_version`
    os="Debian Linux $ver"
fi
if [ "$os" = "" -a -f /etc/mandrake-release ]; then
    os=`cat /etc/mandrake-release`
fi
if [ "$os" = "" ]; then
    os=`uname -sr 2>/dev/null`
fi
echo 'os:' $os
echo --- END device_info

# getHostInfo
echo --- START host_info
# First, gather information about the processor.
cpuspeed=`egrep '^(cpu MHz|cpu clock|clock)' /proc/cpuinfo | cut -f2 -d: | sed -e 's/\.[0-9]*//' -e 's/Mhz//i' -e 's/ //g' | head -n 1`

cputype=`egrep '^cpu[^a-z]*:' /proc/cpuinfo | sort -u | cut -f2 -d: | sed -e 's/^ //' |  head -n 1`
if [ "${cputype}" = "" ]; then
    cputype=`egrep '^model name' /proc/cpuinfo | sort -u | cut -f2 -d: | sed -e 's/^ //' |  head -n 1`
fi
if [ "${cputype}" = "" ]; then
    cputype=`egrep '^arch' /proc/cpuinfo | sort -u | cut -f2 -d: | sed -e 's/^ //' |  head -n 1`
fi
if [ "${cputype}" = "" ]; then
    cputype=`egrep '^(cpu model|family|vendor_id|machine|Processor)' /proc/cpuinfo | sort -u | cut -f2 -d: | sed -e 's/^ //' |  head -n 1`
fi

# This value is the number of logical processors available
logical=`egrep '^[pP]rocessor' /proc/cpuinfo | sort -u | wc -l`

physical=0
cores=0
threads_per_core=0

if [ "${cputype:0:2}" = "PA" ]; then
    # check if it is a PA-RISC processor
    cpufamily=`egrep '^(cpu family)' /proc/cpuinfo | sort -u | cut -f2 -d: | sed -e 's/^ //' |  head -n 1`
    if [ "${cpufamily:0:7}" = "PA-RISC" ]; then
        cputype="${cpufamily} ${cputype}"
        model=`egrep '^(model name)' /proc/cpuinfo | sort -u | cut -f2 -d: | sed -e 's/^ //' |  head -n 1`
        
        if [ "${model}" != "" ]; then
            echo 'model:' ${model}
        fi
    fi
fi

if  [ "${cputype}" = "Alpha" ]; then
    # Alpha doesn't have one entry per processor.
    cpumodel=`egrep '^(cpu model)' /proc/cpuinfo | sort -u | cut -f2 -d: | sed -e 's/^ //' |  head -n 1`
    cputype="${cputype} ${cpumodel}"
    cores=1
    threads_per_core=1
    physical=`egrep '^(cpus detected)' /proc/cpuinfo | sort -u | cut -f2 -d: | sed -e 's/^ //' |  head -n 1`
    if [ "$physical" = "" ]; then
        physical=1
    fi
    logical=${physical}
    model=`egrep '^(platform string)' /proc/cpuinfo | sort -u | cut -f2 -d: | sed -e 's/^ //' |  head -n 1`
    serial=`egrep '^(system serial number)' /proc/cpuinfo | sort -u | cut -f2 -d: | sed -e 's/^ //' |  head -n 1`
    if [ "${serial}" != "" ]; then
        echo 'serial:' ${serial}
    fi
    
    if [ "${model}" != "" ]; then
        echo 'model:' ${model}
    fi
    
    cpuspeed=`egrep '^(cycle frequency \[Hz\])' /proc/cpuinfo | cut -f2 -d: | sed -e 's/\.[0-9]*//' -e 's/Mhz//i' -e 's/ //g' | head -n 1`
    if [ "${cpuspeed}" != "" ]; then
        cpuspeed=`expr ${cpuspeed} / 1000000`
    fi

elif [ ${logical} -eq 1 ]; then
    # The common case of one logical processor, no need to do
    # anything more fancyful
    #
    physical=1
    cores=1
    threads_per_core=1

elif [ ${logical} -ge 2 ]; then
    # The "siblings" attribute, when present, if fairly reliable. It
    # indicates how many logical processors are running on each
    # physical. Each of those 'sibling' could be a core or a thread
    # or a combination of both.
    siblings=`egrep '^siblings' /proc/cpuinfo | head -n 1 | awk '{print $3}' | tr -d '[:space:]'`
    if [ "${siblings}" = "" ]; then
        siblings=0
    fi
    
    # Some processors are described as dual or quad core in their description.
    # Use this as a hint to confirm the number of cores reported by the OS
    # or use outright if the OS has no clue.
    isDualCore=`echo ${cputype} | egrep -i 'dual.?(core|cpu)'`
    isQuadCore=`echo ${cputype} | egrep -i 'quad.?(core|cpu)'`
    if [ "${isDualCore}" != "" ]; then
        cores_hint=2
    elif [ "${isQuadCore}" != "" ]; then
        cores_hint=4
    else
        isOpteron=`echo ${cputype} | egrep -i 'amd +opteron *\(tm\) +processor.*[0-9][0-9][0-9]'`
        
        if [ "${isOpteron}" != "" ]; then
            # time to try some common CPU detection.
            opteron_number=`expr match "${cputype}" '.*\(.[0-9][0-9][0-9]\)'`
            if [ ${opteron_number} -lt 1000 ]; then
                # Right now numbers below x60 are 1 core
                # Over x60 are dual core
                if [ ${opteron_number:2:1} -lt 6 ]; then
                    cores_hint=1
                    siblings=1
                else
                    cores_hint=2
                    siblings=2
                fi
            else
                if [ ${opteron_number:1:1} -eq 2 ]; then
                    cores_hint=2
                    siblings=2
                elif [ ${opteron_number:1:1} -eq 3 ]; then
                    cores_hint=4
                    siblings=4
                elif [ ${opteron_number:1:1} -eq 4 ]; then
                    cores_hint=6
                    siblings=6
                fi
            fi
        else
            cores_hint=0
        fi
    fi

    # Use "cpu cores" if available. Note that "core id" is not exploitable
    # as the system sometimes assigns a core id to each core on the system
    # and sometimes reuse the same id on two cores on separate processors.
    cores=`egrep '^cpu cores' /proc/cpuinfo | head -n 1 | awk '{print $4}' | tr -d '[:space:]'`
    if [ "${cores}" = "" ]; then
        cores=${cores_hint}
    elif [ ${cores_hint} -ne 0 ]; then
        if [ ${cores_hint} -ne ${cores} ]; then
            cores=0
        fi
    fi
    
    # Do some fixing.
    if [ ${cores} -gt ${siblings} ]; then
        # Taking a risk here, but multicore hyperthreaded cpus are
        # not that common 
        siblings=${cores}
    fi
    
    # If we do not have access to sibling it is not possible to figure out
    # the number of physical processors from the OS

    if [ ${cores} -eq ${logical} ]; then
        # A special case, we got the number of cores, but not the siblings
        # In that case if the nomber of core is the same as the number of logical
        # CPU it is safe to assume one physical package.
        physical=1
        threads_per_core=1
        
    elif [ ${siblings} -ne 0 ]; then
        # Check if the number of physical CPUs can be determined. Unfortunately
        # old version of linux sometimes use the same physical ID for separate
        # processors. So this value is retrieved only if we can confirm it via the 
        # siblings
        physical=`egrep '^(physical id)|(Physical processor ID)' /proc/cpuinfo | cut -f2 -d: | sed -e 's/^ //' | sort -u | wc -l`
    
        calculated=`expr ${logical} / ${siblings}`
        
        if [ ${calculated} -ne ${physical} ]; then
            # conflicting information. Better not to take a position rather
            # than being wrong
            if [ ${cores} -eq 0 ]; then
                physical=0
            else
                physical=${calculated}
            fi
        fi
        
        # There is no easy way to find out the number of threads running in each
        # processor. Relying on the htt flag is not an option as this flag is
        # set on processors on which we know there is not hyperthreading at all.
        # So this value is set only if we get good data on cores and siblings.
        if [ ${cores} -ne 0 ]; then
            threads_per_core=`expr ${siblings} / ${cores}`
        fi

    fi
    
fi

# Please do not remove the next line.
# It is used as an anchor for the test suite.
print=1


ram=`awk '/^MemTotal:/ {print $2 "KB"}' /proc/meminfo 2>/dev/null`

if [ -f /usr/sbin/esxcfg-info ]; then
    # On a VMWare ESX controller, report the *real* hardware information
    file=/tmp/tideway-hw-$$
    PRIV_ESXCFG /usr/sbin/esxcfg-info > ${file} 2>/dev/null
    if [ $? -eq 0 ]; then
        physical=`grep "Num Packages." ${file} | sed -e "s/[^0-9]//g"`
        logical=`grep "Num Cores." ${file} | sed -e "s/[^0-9]//g"`
        cores=`expr ${logical} / ${physical}`
        total_threads=`grep "Num Threads." ${file} | sed -e "s/[^0-9]//g"`
        threads_per_core=`expr ${total_threads} / ${logical}`
        cpuspeed=`egrep -i "cpu ?speed\." ${file} | head -n 1 | sed 's/[^0-9]*//g' | awk '{printf( " @ %.1f GHz\n", $1/1024**3)}'`
        tmp=`echo ${cputype} | sed 's/ @.*$//'`
        cputype="${tmp} ${cpuspeed}"
        ram=`grep "Physical Mem." ${file} | sed 's/[^0-9]*//g'`B
    else
        print=0
    fi
    rm -f ${file}
fi
if [ -f /opt/xensource/bin/xe ]; then
    print=0
    # /proc/cpuinfo reports incorrectly for Xen domains, use "xe"
    # However, this can only tell us the logical processor count, not
    # physical, core count or threads per core
    XE=/opt/xensource/bin/xe
    cores=0
    threads_per_core=0
    physical=0
    cpu_list=`PRIV_XE $XE host-cpu-list 2>/dev/null`
    if [ $? -eq 0 ]; then

        logical=`echo "$cpu_list" | grep uuid | wc -l`
        uuid=`echo "$cpu_list" | grep uuid | head -n 1 | cut -f2 -d: | awk '{print $1;}'`
        cputype=`PRIV_XE $XE host-cpu-param-get uuid=$uuid param-name=modelname`
        cpuspeed=`PRIV_XE $XE host-cpu-param-get uuid=$uuid param-name=speed`

        # /proc/meminfo reports incorrectly for Xen domains, use "xe"
        uuid=`PRIV_XE $XE host-list | grep uuid | head -n 1 | cut -f2 -d: | awk '{print $1;}'`
        ram=`PRIV_XE $XE host-param-get uuid=$uuid param-name=memory-total`
        print=1
    fi
fi

echo 'kernel:' `uname -r`

if [ ${print} == 1 ]; then
    # Report processor/memory info
    if [ ${logical} -ne 0 ]; then
        echo 'num_logical_processors:' ${logical}
    fi
    if [ ${cores} -ne 0 ]; then
        echo 'cores_per_processor:' ${cores}
    fi
    if [ ${threads_per_core} -ne 0 ]; then
        echo 'threads_per_core:' ${threads_per_core}
    fi
    if [ ${physical} -ne 0 ]; then
        echo 'num_processors:' ${physical}
    fi
    if [ "${cputype}" != "" ]; then
        echo 'processor_type:' ${cputype}
    fi
    if [ "${cpuspeed}" != "" ]; then
        echo 'processor_speed:' ${cpuspeed}
    fi
    if [ "${ram}" != "" ]; then
        echo 'ram:' ${ram}
    fi
fi

# Get uptime in days and seconds
uptime | awk '
{ 
  if ( $4 ~ /day/ ) { 
    print "uptime:", $3; 
    z = split($5,t,":"); 
    printf( "uptimeSeconds: %d\n", ($3 * 86400) + (t[1] * 3600) + (t[2] * 60) ); 
  } else { 
    print "uptime: 0"; 
    z = split($3,t,":"); 
    print "uptimeSeconds:", (t[1] * 3600) + (t[2] * 60); 
  }
}'

# Can we get information from the BIOS?
if [ -f /usr/sbin/dmidecode ]; then
    PRIV_DMIDECODE /usr/sbin/dmidecode 2>/dev/null | awk '/DMI type 1,/,/^Handle 0x0*[2-9]+0*/ {
        if( $1 ~ /Manufacturer:/ ) { sub(".*Manufacturer: *","");  printf( "vendor: %s\n", $0 ); }
        if( $1 ~ /Vendor:/ ) { sub(".*Vendor: *","");  printf( "vendor: %s\n", $0 ); }
        if( $1 ~ /Product/ && $2 ~ /Name:/ ) { sub(".*Product Name: *",""); printf( "model: %s\n", $0 ); }
        if( $1 ~ /Product:/ ) { sub(".*Product: *",""); printf( "model: %s\n", $0 ); }
        if( $1 ~ /Serial/ && $2 ~ /Number:/ ) { sub(".*Serial Number: *",""); printf( "serial: %s\n", $0 ); }
    }'
fi
if [ -f /usr/sbin/hwinfo ]; then
    PRIV_HWINFO /usr/sbin/hwinfo --bios 2>/dev/null | awk 'BEGIN { flag=0; }
/System Info: #[0-9]/ { flag=1; }
/Manufacturer:/ { if (flag) { sub(".*Manufacturer: *","");  gsub( "\"", ""); printf( "vendor: %s\n", $0 ); } }
/Product:/ { if (flag) { sub(".*Product: *","");  gsub( "\"", ""); printf( "model: %s\n", $0 ); } }
/Serial:/ { if (flag) { sub(".*Serial: *","");  gsub( "\"", ""); printf( "serial: %s\n", $0 ); } }
/Board Info: #[0-9]/ { exit; }'
fi

# PPC64 LPAR?
if [ -f /proc/ppc64/lparcfg ]; then
    sed -e 's/=/: /' /proc/ppc64/lparcfg | egrep '^[a-z]' | sed -e 's/^serial_number/serial/' -e 's/^system_type/model/' -e 's/partition_id/lpar_id/' -e 's/^group/lpar_partition_group_id/' -e 's///'
fi
echo 'begin df:'
df -k -x nfs 2>/dev/null
echo 'end df'
echo --- END host_info

# getInterfaceList
echo --- START ifconfig
ifconfig -a 2>/dev/null
ETHTOOL=""
if [ -f /sbin/ethtool ]; then
    ETHTOOL=/sbin/ethtool
else
    if [ -f /usr/sbin/ethtool ]; then
        ETHTOOL=/usr/sbin/ethtool
    fi
fi
MIITOOL=""
if [ -f /sbin/mii-tool ]; then
    MIITOOL=/sbin/mii-tool
fi
if [ "$ETHTOOL" != "" ]; then
    echo 'begin ethtool:'
    for i in `ifconfig -a 2>/dev/null | egrep '^[a-z]' | awk '{print $1;}'`
    do
        echo Begin-interface: $i
        PRIV_ETHTOOL $ETHTOOL $i 2>/dev/null
        echo End-interface: $i
    done
    echo 'end ethtool:'
fi
if [ "$MIITOOL" != "" ]; then
    echo 'begin mii-tool:'
    for i in `ifconfig -a | egrep '^[a-z]' | awk '{print $1;}'`
    do
        echo Begin-interface: $i
        PRIV_MIITOOL $MIITOOL -v $i 2>/dev/null
        echo End-interface: $i
    done
    echo 'end mii-tool:'
fi
echo --- END ifconfig

# getNetworkConnectionList
echo --- START netstat
PRIV_NETSTAT netstat -aneep --tcp --udp 2>/dev/null
echo --- END netstat

# getProcessList
echo --- START ps
ps -eo pid,ppid,uid,user,cmd --no-headers -ww 2>/dev/null
echo --- END ps

# getPatchList
#   ** DISABLED **

# getProcessToConnectionMapping
echo --- START lsof-i
PRIV_LSOF lsof -l -n -P -F ptPTn -i 2>/dev/null
echo --- END lsof-i

# getPackageList
echo --- START rpmx
rpm -qa --queryformat 'begin\nname: %{NAME}\nversion: %{VERSION}\nrelease: %{RELEASE}\narch: %{ARCH}\ninstall_time: %{INSTALLTIME}\nend\n' 2>/dev/null
echo --- END rpmx

echo --- START rpm
rpm -qa --queryformat %{NAME}:%{VERSION}:%{RELEASE}@ 2>/dev/null
echo
echo --- END rpm

echo --- START dpkg
COLUMNS=256 dpkg -l '*' | egrep '^ii '
echo --- END dpkg

# getHBAList
echo --- START hbainfo
PATH=/usr/sbin/hbanyware:/usr/sbin/lpfc:/usr/sbin/lpfs:/opt/EMLXemlxu/bin:$PATH
echo begin lputil_listhbas
echo 0 | PRIV_LPUTIL lputil listhbas 2>/dev/null
echo end lputil_listhbas

echo begin lputil_fwlist
i=0
max_count=`echo 0 | PRIV_LPUTIL lputil count 2>/dev/null`
if [ $? -eq 0 ]; then
    while [ $i -lt "$max_count" ]
    do
        echo Board $i
        echo 0 | PRIV_LPUTIL lputil fwlist $i 2>/dev/null | grep "Functional Firmware" || echo "Functional Firmware: None"
        i=`expr $i + 1`
    done
fi
echo end lputil_fwlist

echo begin hbacmd_listhbas
PRIV_HBACMD hbacmd ListHBAs 2>/dev/null
echo end hbacmd_listhbas

echo begin hbacmd_hbaattr
for WWPN in `PRIV_HBACMD hbacmd ListHBAs 2>/dev/null | awk '/Port WWN/ {print $4;}'`
do
    PRIV_HBACMD hbacmd HBAAttrib $WWPN 2>/dev/null
done
echo end hbacmd_hbaattr

echo begin emlxadm_get_port_attrs
PRIV_EMLXADM emlxadm devctl -y get_port_attrs wwn 2>/dev/null
echo end emlxadm_get_port_attrs

echo begin emlxadm_get_fw_rev
PRIV_EMLXADM emlxadm devctl -y get_fw_rev 2>/dev/null
echo end emlxadm_get_fw_rev
echo --- END hbainfo


