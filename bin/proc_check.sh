#!/usr/bin/env sh

# -------------------------------------------------------------------------------
# Name:			proc_check
# Author: 		Wei.Shen 
# Status: 		Development
# Version		v1.0
# Description: 	Check the process running status 
#     Get the warning & critical threshold ,
#     and warning & critical mail receiver
#     from config file(cfg/*.cfg)
#     Configure sample:
#	ITEM	NAME	PATTERN	FLAG	WARNING	CRITICL	WARNING_MAIL CRITICAL_MAIL_RCV
#	proc	JavaP	java	<	1	1	sysadmin.mail	datacenter.mail
#
# History:		
#	Feb 11 2015 	Wei		v1.0	Creation 
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
awk '$1 !~ /^#/ && NF == 8' $CFGDIR/*.cfg|grep ^proc |sort|uniq  > $VARDIR/$PN.$$

while read ITEM N P F W C WM CM
do
	[ -f $ETCDIR/$WM ] && WM=$(cat $ETCDIR/$WM)
	[ -f $ETCDIR/$CM ] && CM=$(cat $ETCDIR/$CM)
	WM=${WM:-$PA}
	CM=${CM:-$PA}
	
	case "$OS" in 
	"Linux"|"AIX"|"SunOS")
		NOW=$(ps -ef|grep $P|grep -v grep |wc -l)
		ps -eaf|grep $P|grep -v grep > $TMPFILE
		;;
	*)
		eerror_msg "Unsupported OS - $OS"
		;;
	esac
	# Different process for < or > flag
	case $F in 
	"<")
		DESC1="less than"
		if [ $NOW -lt $C ];then
			DESC2="Critical"
			DESC3=$C
			DESC4=$CM
		elif [ $NOW -lt $W ];then
			DESC2="Warning"
			DESC3=$W
			DESC4=$WM
		fi
		;;
	">")
		DESC1="greater than"
		;;
	*)
		error_msg "Unknown judge FLAG - $F " 
		break
		;;
	esac
	
	# if the value meet the warning or critical threshold
	if [ ! -z "$DESC2" ];then
       	info_msg "$TITLE-$ITEM/$N ($P) Count ($NOW) is $DESC1 $DESC3. $DESC2 threshold is $DESC3."  >$MAILFILE
		echo "" >>$MAILFILE
		cat $TMPFILE >>$MAILFILE	
		send_mail $MAILFILE $MAIL_SENDER "$DESC2 ALARM $HOST $TITLE-$N $ITEM ($NOW) is $DESC1 $DESC3." $DESC4
	
		DESC1=""
		DESC2=""
		DESC3=""
		DESC4=""
		rm $MAILFILE
	fi
	
	rm $TMPFILE

	info_msg "Current $ITEM value of ${N} is ${NOW}"
done < $VARDIR/$PN.$$
