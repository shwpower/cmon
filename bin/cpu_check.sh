#!/usr/bin/env sh

# -------------------------------------------------------------------------------
# Name:			cpu_check
# Author: 		Wei.Shen 
# Status: 		Development
# Version		v1.0
# Description: 	Check the CPU utlization with sar
#				Get the warning & critical threshold ,
#						and warning & critical mail receiver
#						from config file(cfg/*.cfg)
#			Configure sample:
#			ITEM	NAME	FLAG	WARNING	CRITICL	WARNING_MAIL CRITICAL_MAIL_RCV
#			cpu		cpu		<		60		90		sysadmin.mail	datacenter.mail
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
awk '$1 !~ /^#/ && NF == 7' $CFGDIR/*.cfg|grep ^cpu |sort|uniq  > $VARDIR/$PN.$$

while read ITEM N F W C WM CM
do
	[ -f $ETCDIR/$WM ] && WM=$(cat $ETCDIR/$WM)
	[ -f $ETCDIR/$CM ] && CM=$(cat $ETCDIR/$CM)
	WM=${WM:-$PA}
	CM=${CM:-$PA}

	# sar command to get 6*5ms cpu status 
	sar 5 6 > $TMPFILE

	case "$OS" in 
	"Linux")
		case "$ITEM" in
		"cpu")	NOW=$(cat $TMPFILE|tail -1|awk '{print int(100-$8)}')
			;;
		*)	error_msg "Unknown item - $ITEM"
			break
			;;
		esac
		;;		
	"AIX")
		case "$ITEM" in
		"cpu")	NOW=$(cat $TMPFILE|tail -1|awk '{print int(100-$5)}')
			;;
		*)	error_msg "Unknown item - $ITEM"
			break
			;;
		esac
		;;

	"SunOS")
		case "$ITEM" in
		"cpu")	NOW=$(cat $TMPFILE|tail -1|awk '{print int(100-$5)}')
			;;
		*)	error_msg "Unknown item - $ITEM"
			break
			;;
		esac
		;;

	*)
		error_msg "Unsupported OS - $OS"
		;;
	esac

	# Judge the CPU usage more than Critical threshold
	if [ $NOW -ge $C ];then
        info_msg "$TITLE-$ITEM utilization is $NOW%. Critical threshold is ${C}%."  >$MAILFILE
		echo "" >>$MAILFILE
		cat $TMPFILE >>$MAILFILE	
		send_mail $MAILFILE $MAIL_SENDER "Critical ALARM $HOST $TITLE-$ITEM Utilization($NOW%) is greater than $C%." $CM	
		rm $MAILFILE
	# Judge the CPU usage more than Warning threshold
	elif [ $NOW -ge $W ];then
        info_msg "$TITLE-$ITEM utilization is $NOW%. Warning threshold is ${W}%" >$MAILFILE
		echo "" >>$MAILFILE
		cat $TMPFILE >>$MAILFILE	
		send_mail $MAILFILE $MAIL_SENDER "Warning ALARM $HOST $TITLE-$ITEM Utilization($NOW%) is greater than $W%." $WM
		rm $MAILFILE
	fi	

	rm $TMPFILE

	info_msg "Current $ITEM value of ${PN} is ${NOW}%"
done < $VARDIR/$PN.$$

rm $VARDIR/${PN}.$$
