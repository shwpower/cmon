#!/usr/bin/env sh

# -------------------------------------------------------------------------------
# Name:			mem_check
# Author: 		Wei.Shen 
# Status: 		Development
# Version		v1.0
# Description: 	Check the Memory utlization 
#				Get the warning & critical threshold ,
#						and warning & critical mail receiver
#						from config file(cfg/*.cfg)
#			Configure sample:
#			ITEM	NAME	FLAG	WARNING	CRITICL	WARNING_MAIL CRITICAL_MAIL_RCV
#			fs	/	<	60	90	sysadmin.mail	datacenter.mail
#			fsinode	/	<	10	40	sysadmin.mail	datacenter.mail
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
awk '$1 !~ /^#/ && NF == 7' $CFGDIR/*.cfg|grep ^fs |sort|uniq  > $VARDIR/$PN.$$

while read ITEM N F W C WM CM
do
	[ -f $ETCDIR/$WM ] && WM=$(cat $ETCDIR/$WM)
	[ -f $ETCDIR/$CM ] && CM=$(cat $ETCDIR/$CM)
	WM=${WM:-$PA}
	CM=${CM:-$PA}
	
	case "$OS" in 
	"Linux")
		case "$ITEM" in
		"fs")	NOW=$(df -k $N|tail -1|awk '{if(NF>5) {print $5} else {print $4}}'|tr -d %)
			df -k > $TMPFILE
			;;
		"fsinode") NOW=$(df -i $N|tail -1|awk '{if(NF>5) {print $5} else {print $4}}'|tr -d %)
			df -i > $TMPFILE
			;;	
		*)	error_msg "Unknown item of $ITEM - $N"
			break
			;;
		esac
		;;		
	"AIX")
		case "$ITEM" in
		"fs")	NOW=$(df -k $N |awk 'NR == 2 {print $4}'|tr -d %)
			;;
		"fsinode") NOW=$(df -k $N |awk 'NR == 2 {print $6}'|tr -d %)
			;;
		*)	error_msg "Unknown item of $ITEM - $N"
			break
			;;
		esac
		;;

	"SunOS")
		case "$ITEM" in
		"fs")	NOW=$(df -k $N|tail -1|awk '{print $5}'|tr -d %)
			df -k > $TMPFILE
			;;
		"fsinode") NOW=$(df -oi $N|tail -1|awk '{if(NF>5) {print $5} else {print $4}}'|tr -d %)
			df -oi > $TMPFILE 2>/dev/null
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

	# Judge the fs/fsinode usage more than Critical threshold
	if [ $NOW -ge $C ];then
        info_msg "$TITLE-$N $ITEM utilization is $NOW%. Critical threshold is ${C}%."  >$MAILFILE
		echo "" >>$MAILFILE
		cat $TMPFILE >>$MAILFILE	
		send_mail $MAILFILE $MAIL_SENDER "Critical ALARM $HOST $TITLE-$N $ITEM Utilization($NOW%) is greater than $C%." $CM	
		rm $MAILFILE
	# Judge the fs/fsinode usage more than Warning threshold
	elif [ $NOW -ge $W ];then
        info_msg "$TITLE-$N $ITEM utilization is $NOW%. Warning threshold is ${W}%." >$MAILFILE
		echo "" >>$MAILFILE
		cat $TMPFILE >>$MAILFILE	
		send_mail $MAILFILE $MAIL_SENDER "Warning ALARM $HOST $TITLE-$N $ITEM Utilization($NOW%) is greater than $W%." $WM
		rm $MAILFILE
	fi	
	
	rm $TMPFILE

	info_msg "Current $ITEM value of ${N} is ${NOW}%"
done < $VARDIR/$PN.$$

rm $VARDIR/${PN}.$$
