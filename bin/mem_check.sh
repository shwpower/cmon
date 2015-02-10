#!/usr/bin/env sh

# -------------------------------------------------------------------------------
# Name:			mem_check
# Author: 		Wei.Shen 
# Status: 		Development
# Version		v1.0
# Description: 	Check the Memory utlization with sar
#				Get the warning & critical threshold ,
#						and warning & critical mail receiver
#						from config file(cfg/*.cfg)
#			Configure sample:
#			ITEM	NAME	FLAG	WARNING	CRITICL	WARNING_MAIL CRITICAL_MAIL_RCV
#			mem		ram		<		60		90		sysadmin.mail	datacenter.mail
#			mem		swap	<		10		40		sysadmin.mail	datacenter.mail
#
# History:		
#	Feb 10 2015 	Wei		v1.0	Creation 
#
#
# -------------------------------------------------------------------------------

export PN=$(basename $0 ".sh")
export LOGFILE=$LOGDIR/${PN}.log
export TMPFILE=$VARDIR/${PN}.tmp
export MAILFILE=$VARDIR/${PN}.mail

# Set executing output
#set -x 

# Load the common function 
. $FPATH/common.sh

# get the uppercase exclude "_check.sh" from program name
TITLE=$(basename $0 "_check.sh"|awk '{print toupper($1)}')
# Record the pattern string into temporary file
awk '$1 !~ /^#/ && NF == 7' $CFGDIR/*.cfg|grep ^mem |sort|uniq  > $VARDIR/$PN.$$

while read ITEM N F W C WM CM
do
	[ -f $ETCDIR/$WM ] && WM=$(cat $ETCDIR/$WM)
	[ -f $ETCDIR/$CM ] && CM=$(cat $ETCDIR/$CM)
	WM=${WM:-$PA}
	CM=${CM:-$PA}
	
	case "$OS" in 
	"Linux")
		case "$N" in
		"ram")	NOW=$(free -m |grep Mem|awk '{print int($3*100/$2)}')
			CACHE=$(free -m |grep Mem|awk '{print int($7*100/$2)}')
			# Clear the cache size of memory
			if [ $CACHE -gt 60 ]; then
				info_msg "Cache_Size > 60%, do cleanup"	
				sync;sync; sleep 5; echo 1 > /proc/sys/vm/drop_caches
			fi
			;;
		"swap") NOW=$(free -m |grep Swap|awk '{print int($3*100/$2)}')
			;;	
		*)	error_msg "Unknown item of $ITEM - $N"
			break
			;;
		esac
		free -m >$TMPFILE		
		;;		
	"AIX")
		case "$N" in
		"ram")	NOW=$(svmon -G|grep memory|awk '{print int($3*100/$2)}')
			svmon -G > $TMPFILE
			;;
		"swap") NOW=$(lsps -s|grep -v Paging|awk '{print $2}'|tr -d '%')
			lsps -s > $TMPFILE
			;;	
		*)	error_msg "Unknown item of $ITEM - $N"
			break
			;;
		esac
		;;

	"SunOS")
		case "$N" in
		"ram")	FREE=$(echo "::memstat" | mdb -k|grep Free|awk '{sum+=$4}END{print sum}')
			NOW=$(echo "::memstat" | mdb -k|grep Total|awk '{print int(($3-f)*100/$3)}' f=$FREE)
			echo "::memstat" | mdb -k > $TMPFILE
			;;
		"swap") NOW=$(swap -s|awk -F\= '{print $2}'|sed 's/k used//g'|sed 's/k available//g'|awk '{print int($1*100/($1+$2))}')
			swap -s > $TMPFILE
			;;	
		*)	error_msg "Unknown item of $ITEM - $N"
			break
			;;
		esac
		;;

	*)
		eerror_msg "Unsupported OS - $OS"
		;;
	esac

	# Judge the Memory usage more than Critical threshold
	if [ $NOW -ge $C ];then
        info_msg "$TITLE-$N utilization is $NOW%. Critical threshold is ${C}%."  >$MAILFILE
		echo "" >>$MAILFILE
		cat $TMPFILE >>$MAILFILE	
		send_mail $MAILFILE $MAIL_SENDER "Critical ALARM `hostname` $TITLE-$N Utilization($NOW%) is greater than $C%." $CM	
		rm $MAILFILE
	# Judge the Memory usage more than Warning threshold
	elif [ $NOW -ge $W ];then
        info_msg "$TITLE-$N utilization is $NOW%. Warning threshold is ${W}%." >$MAILFILE
		echo "" >>$MAILFILE
		cat $TMPFILE >>$MAILFILE	
		send_mail $MAILFILE $MAIL_SENDER "Warning ALARM `hostname` $TITLE-$N Utilization($NOW%) is greater than $W%." $WM
		rm $MAILFILE
	fi	
	
	rm $TMPFILE

	info_msg "Current $N value of ${ITEM} is ${NOW}%"
done < $VARDIR/$PN.$$

rm $VARDIR/${PN}.$$
