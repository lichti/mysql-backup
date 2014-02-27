#!/bin/bash

###
# MySQL Backup
# Gustavo Lichti - gustavo.lichti@kanui.com.br
###

##### Config variables #####
# ************ Database ************
DB_HOST=127.0.0.1
DB_NAME=***DB***
DB_USER=***USER***
DB_PASSWORD=***PASS***

# ************ Dump ************
DB_DUMP_OPTIONS="-R --skip-lock-tables"

# ************ Email ************
EMAIL_TO="gustavo.lichti@kanui.com.br"
EMAIL_TITLE="[Backup] DB $DB_NAME"

# ************ Storage Backup ************
HOURS=72
DAYS=7
WEEKS=4

# ************ PATHs ************
BKP_PATH=/backup/$DB_NAME
BKP_HOURLY=$BKP_PATH/hourly
BKP_DAILY=$BKP_PATH/daily
BKP_WEEKLY=$BKP_PATH/weekly

# ************ File name ************
[ $# -gt 0 ] && FILE=$(date +%Y%m%d-%H)$DB_NAME.gz.$(date +%s).test  || FILE=$(date +%Y%m%d-%H)$DB_NAME.gz

# ************ Commands ************
CMD_TEST_QUERY=
CMD_PROD="mysqldump -h$DB_HOST -u$DB_USER --password=$DB_PASSWORD $DB_NAME $DB_DUMP_OPTIONS | gzip -c > $BKP_HOURLY/$FILE"
CMD_TEST="cat /etc/passwd > $BKP_HOURLY/$FILE"


##### Process Start #####

START=$(date)
[ ! -d $BKP_PATH ] && mkdir -p $BKP_PATH
[ ! -d $BKP_HOURLY ] && mkdir -p $BKP_HOURLY
[ ! -d $BKP_DAILY ] && mkdir -p $BKP_DAILY
[ ! -d $BKP_WEEKLY ] && mkdir -p $BKP_WEEKLY
[ $# -gt 0 ] &&	echo "TEST"
[ $# -gt 0 ] && eval $CMD_TEST || eval $CMD_PROD
[ $# -gt 0 ] && EMAIL_TITLE="$(date +%s)-$EMAIL_TITLE"

if [ $(date +%H) -eq 0 ]; then
	ln -v $BKP_HOURLY/$FILE $BKP_DAILY/$FILE
	if [ $(date +%u) -eq 7 ]; then
		ln -v $BKP_HOURLY/$FILE $BKP_DAILY/$FILE
	fi
fi
STOP=$(date)

RM_H=$(find $BKP_HOURLY -mmin +$(( $HOURS * 60 )) -exec rm -v {} \;)
RM_D=$(find $BKP_DAILY -mmin +$(( $DAYS * 24 * 60 )) -exec rm -v {} \;)
RM_W=$(find $BKP_WEEKLY -mmin +$(( $WEEKS * 7 * 24 * 60 )) -exec rm -v {} \;)

DF=$(df -h | grep -v tmpfs)
LS_L=$(ls -lh $BKP_HOURLY/$FILE | cut -d\  -f5,6,7,8,9)
LS_H=$(ls -lh $BKP_HOURLY | tac | cut -d\  -f5,6,7,8,9 | cat -b)
LS_D=$(ls -lh $BKP_DAILY  | tac | cut -d\  -f5,6,7,8,9 | cat -b)
LS_W=$(ls -lh $BKP_WEEKLY | tac | cut -d\  -f5,6,7,8,9 | cat -b)
TEST_QUERY=$( test -n "$CMD_TEST_QUERY"  && echo "Last MySQL Sync: $CMD_TEST_QUERY")

MSG=$(echo -e "
$TEST_QUERY
Started: $START
Ended: $STOP\n
Disk Status:\n$DF\n
Last Backup: $LS_L\n
Weekly Backups (Max: $WEEKS):\n$LS_W\n
Daily Backups (Max: $DAYS):\n$LS_D\n
Hourly Backup (Max $HOURS):\n$LS_H\n
Removed Backups:\n$RM_H\n$RM_D\n$RM_W\n
")
EMAIL_TITLE="$EMAIL_TITLE - $FILE"
mail -s "$EMAIL_TITLE" $EMAIL_TO <<< "$MSG"

[ $# -gt 0 ] && rm -rf $BKP_HOURLY/*.test
