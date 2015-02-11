#!/usr/bin/env sh

# -------------------------------------------------------------------------------
# Name:			log_check
# Author: 		Wei.Shen 
# Status: 		Development
# Version		v1.0
# Description: 		Check the log file status (pattern file)
#			Get the warning & critical pattern file ,
#			and warning & critical mail receiver
#			from config file(cfg/*.cfg)
#	Configure sample:
#	ITEM	NAME	FLAG	WARNING	CRITICL	WARNING_MAIL CRITICAL_MAIL_RCV
#	log	/var/log/messages < messages.warning messages.critical	sysadmin.mail	datacenter.mail
# Required:	grep, egrep
#
# History:		
#	Feb 10 2015 	Wei	v1.0	Creation 
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

## For AIX Errpt
if [ "$OS" == "AIX" ];then
	errpt |head -1 > /tmp/errpt.log
	errpt |awk '{if(NR>1) print}' |grep -n '?*'|sort -rn|cut -d ':' -f2 >> /tmp/errpt.log
fi

# get the uppercase exclude "_check.sh" from program name
TITLE=$(basename $0 "_check.sh"|awk '{print toupper($1)}')
# Record the pattern string into temporary file (7 columns)
awk '$1 !~ /^#/ && NF == 7' $CFGDIR/*.cfg|grep ^log |sort|uniq  > $VARDIR/$PN.$$

while read ITEM N F W C WM CM
do
	[ -f $ETCDIR/$WM ] && WM=$(cat $ETCDIR/$WM)
	[ -f $ETCDIR/$CM ] && CM=$(cat $ETCDIR/$CM)
	WM=${WM:-$PA}
	CM=${CM:-$PA}
	
	# Judge whether the log and pattern file exist
	file_exist $N || continue
	file_exist $SCFGDIR/$W || continue
	file_exist $SCFGDIR/$C || continue
	
	# Judge whether file changed - compared the size
	SIZE1=$(ls -l $N|awk '{print $5}')
	TEMPF1=$VARDIR/$PN.1.$(echo $N |tr -s "/" "~")
	TEMPF2=$VARDIR/$PN.2.$(echo $N |tr -s "/" "~")
	
	if [ ! -f "$TEMPF1" ];then
		echo $SIZE1 >$TEMPF1
	else
		read SIZE2 <$TEMPF1
		if [[ $SIZE1 -ne $SIZE2 ]]; then
			rm $TEMPF2 >/dev/null 2>&1
			if [[ $SIZE1 -gt $SIZE2 ]];then
				# The log file has update compared with last time
				# Get the new character from last time
				NEWC=`expr $SIZE1 - $SIZE2`	
				tail -${NEWC}c $N >$TEMPF2
			else
				# The logfile was trucated or one new file 
				cat $N >$TEMPF2
			fi
			## Intiniate the KEYS, FLAG
			FLAG=0; KEYS=""
       		## For Critical Filter string
       		egrep -i -s -f $SCFGDIR/$C $TEMPF2
       		if [ $? -eq 0 ];then
           	    while read ERRKEY
                do
               	    grep -i "$ERRKEY" $TEMPF2 >/dev/null 
              	    if [ "$?" -eq 0 ];then
                        print_msg "Pattern $(echo $ERRKEY|tr -s ' ' '_') found in $N."
                        FLAG=1
                        KEYS=`echo "$ERRKEY,$KEYS"`
               	    fi
           	    done < $SCFGDIR/$C
	            # Match the pattern string in log file
           	    if [ "$FLAG" == "1" ]; then
	                send_mail $TEMPF2 $MAIL_SENDER "Major ALARM $(HOST) $(basename $N) ($KEYS) " $CM
	            fi
					
	            ##Clean up the var FLAG, KEYS
	            FLAG=0
	            KEYS=""
	         else
                ## For Warining Filter string
                egrep -i -s -f $SCFGDIR/$W $TEMPF2
                if [ $? -eq 0 ]; then
                    while read ERRKEY
                    do
        			    grep -i "$ERRKEY" $TEMPF2 >/dev/null 
               		    if [ "$?" -eq 0 ];then
                       		echo "Pattern $(echo $ERRKEY|tr -s ' ' '_') found in $N." >>$LOGFILE
				            FLAG=1
                           	KEYS=`echo "$ERRKEY,$KEYS"`
               		    fi
       		        done  < $SCFGDIR/$W  
		        fi
		        # Match the pattern string in log file
		        if [ "$FLAG" == "1" ]; then
			        send_mail $TEMPF2 $MAIL_SENDER "Warning ALARM $HOST $(basename $N) ($KEYS) " $WM
               	fi

               	##Clean up the var FLAG, KEYS
               	FLAG=0
               	KEYS=""

	        fi
        fi
        # Record the file to temporary file
        echo $SIZE1 >$TEMPF1
    fi

    info_msg "No pattern from ($W & $C) match logfile ${N}"
done < $VARDIR/$PN.$$

rm $VARDIR/${PN}.$$
