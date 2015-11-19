#!/bin/bash
# rotate-backups.sh v0.1
#INSTRUCTINS: Script to clean up a snapshot directory. It does not create the initial snapshots, but works with existing snapshots.
#Snapshots need to be in the form of [BASENAME](date +%F-%H%M%S) for this to work. 
#NOTE: This script should be run at least every RETENTION_DAYS in order for it to make reliable weeklys. Once a day is preferred.
#For example, have another script taking periodic snapshots of a subvolume into a backup folder, preferreably at least every hour.
#Run this script against that directory (maybe once a day) to convert the snapshots into houly,daily,weekly,monthly,yearly snapshots.
# depends on date, find, awk, rev, cut, echo
# date formats need to be in "date +%F-%H%M%S", use a compatable snapshotting script.

##### Configure the following variables to your backup location and desired retention #####
WORKING_DIR="/mnt/btrfs/backups"
BASENAME="minecraft_backup_"
RETENTION_MINUTES=240  	#keep this amount of past minutes (don't delete any subvolumes)
RETENTION_HOURS=72 	#keep this amount of past hours
RETENTION_DAYS=7   	#keep this amount of past days (range from 1 to months retained)
RETENTION_WEEKS=6  	#keep this amount of past weeks (first available subvolume of the week)
RETENTION_MONTHS=12 	#keep this amount of past months (first snapshot of month)
RETENTION_YEARS=5	#keep this amount of past years (first snapshot of the year)
##### END USER CONFIGURED VARIABLES, DO NOT MODIFY ANYTHING BELOW THIS LINE! #####

BACKUP_LIST=(`find "$WORKING_DIR"/"$BASENAME"* -maxdepth 0 -type d ! -name '*LY' | rev | cut -f1 -d'/' | rev`)
CUTOFF_MINUTE=`date +%Y%m%d%H%M --date="-$RETENTION_MINUTES minutes"`	#in format yyyymmddhhmm
CUTOFF_HOUR=`date +%Y%m%d%H --date="-$RETENTION_HOURS hours"`		#in format yyyymmddhh
CUTOFF_DAY=`date +%Y%m%d --date="-$RETENTION_DAYS days"`		#in format yyyymmdd
CUTOFF_WEEK=`date +%Y%W --date="-$RETENTION_WEEKS weeks"`		#in format yyyyWW
CUTOFF_MONTH=`date +%Y%m --date="-$RETENTION_MONTHS months"` 		#in format yyyymm
CUTOFF_YEAR=`date +%Y --date="-$RETENTION_YEARS years"`			#in format yyyy

refresh_lists()
{
	YEARLY_LIST=(`find "$WORKING_DIR"/"$BASENAME"* -maxdepth 0 -type d -name '*YEARLY' | rev | cut -f1 -d'/' | rev`)
	MONTHLY_LIST=(`find "$WORKING_DIR"/"$BASENAME"* -maxdepth 0 -type d -name '*MONTHLY' | rev | cut -f1 -d'/' | rev`)
	WEEKLY_LIST=(`find "$WORKING_DIR"/"$BASENAME"* -maxdepth 0 -type d -name '*WEEKLY' | rev | cut -f1 -d'/' | rev`)
	DAILY_LIST=(`find "$WORKING_DIR"/"$BASENAME"* -maxdepth 0 -type d -name '*DAILY' | rev | cut -f1 -d'/' | rev`)
	HOURLY_LIST=(`find "$WORKING_DIR"/"$BASENAME"* -maxdepth 0 -type d -name '*HOURLY' | rev | cut -f1 -d'/' | rev`)
}

process_years()
{
	local i
	#loop to determine if we even need a yearly snapshot of this subvolume
	for i in ${YEARLY_LIST[*]}
	do
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $1}') -eq "$SUB_YEAR" ]]
		then
#			echo "They match! Already have a yearly for this year."
			return 0 #exit this function as we already have a yearly for this subvolume year
		fi		
	done
	echo -e "Creating YEARLY snapshot"
	#loop to determine if any monthly snapshots are older than current subvolume, if so then use them to create the yearly
	for i in ${MONTHLY_LIST[*]}
	do
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $1}') -eq "$SUB_YEAR" && $(echo ${i#$BASENAME} | awk -F'-' '{printf $2}') -le $SUB_MONTH ]]
		then
			#cp -r "$WORKING_DIR"/"$i" "$WORKING_DIR"/"${i%-MONTHLY}"-YEARLY
			btrfs subvolume snapshot -r "$WORKING_DIR"/"$i" "$WORKING_DIR"/"${i%-MONTHLY}"-YEARLY
			refresh_lists
			return 0
		fi			
	done
	#cp -r "$WORKING_DIR"/"$SUBVOLUME" "$WORKING_DIR"/"$SUBVOLUME"-YEARLY
        btrfs subvolume snapshot -r "$WORKING_DIR"/"$SUBVOLUME" "$WORKING_DIR"/"$SUBVOLUME"-YEARLY
	refresh_lists
}

process_months()
{
	local i
	#loop to determine if we even need a monthly snapshot of this subvolume
	for i in ${MONTHLY_LIST[*]}
	do
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $1 $2}') -eq $SUB_YEAR$SUB_MONTH ]]
		then
#			echo "They match! Already have a MONTHLY for this MONTH."
			return 0 #exit this function as we already have a MONTHLY for this subvolume MONTH
		fi		
	done
	echo -e "Creating MONTHLY snapshot: $SUBVOLUME-MONTHLY"
	#loop to determine if any DAILY snapshots are older than current subvolume, if so then use them to create the MONTHLY
	for i in ${DAILY_LIST[*]}
	do
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $2}') -eq "$SUB_MONTH" && $(echo ${i#$BASENAME} | awk -F'-' '{printf $3}') -le $SUB_DAY ]]
		then
			#cp -r "$WORKING_DIR"/"$i" "$WORKING_DIR"/"${i%-DAILY}"-MONTHLY
			btrfs subvolume snapshot -r "$WORKING_DIR"/"$i" "$WORKING_DIR"/"${i%-DAILY}"-MONTHLY
			refresh_lists
			return 0
		fi			
	done
	#cp -r "$WORKING_DIR"/"$SUBVOLUME" "$WORKING_DIR"/"$SUBVOLUME"-MONTHLY
        btrfs subvolume snapshot -r "$WORKING_DIR"/"$SUBVOLUME" "$WORKING_DIR"/"$SUBVOLUME"-MONTHLY
	refresh_lists
}

process_weeks()
{
	local i
	#loop to determine if we even need a weekly snapshot of this subvolume
	for i in ${WEEKLY_LIST[*]}
	do
		if [[ $(date +%Y%W --date=$(echo ${i#$BASENAME} | awk -F'-' '{printf $1 $2 $3}')) -eq $SUB_WEEK ]]
		then
#			echo "They match! Already have a WEEKLY for this WEEK."
			return 0 #exit this function as we already have a WEEKLY for this subvolume WEEK
		fi		
	done
	echo -e "Creating WEEKLY snapshot: $SUBVOLUME-WEEKLY"
	#loop to determine if any DAILY snapshots are older and within the same week as the current subvolume, if so then use them to create the WEEKLY
	for i in ${DAILY_LIST[*]}
	do
		if [[ $(date +%Y%W --date=$(echo ${i#$BASENAME} | awk -F'-' '{printf $1 $2 $3}')) -eq "$SUB_WEEK" && $(echo ${i#$BASENAME} | awk -F'-' '{printf $3}') -le $SUB_DAY ]]
		then
			#cp -r "$WORKING_DIR"/"$i" "$WORKING_DIR"/"${i%-DAILY}"-WEEKLY
			btrfs subvolume snapshot -r "$WORKING_DIR"/"$i" "$WORKING_DIR"/"${i%-DAILY}"-WEEKLY
			refresh_lists
			return 0
		fi			
	done
	#cp -r "$WORKING_DIR"/"$SUBVOLUME" "$WORKING_DIR"/"$SUBVOLUME"-WEEKLY
        btrfs subvolume snapshot -r "$WORKING_DIR"/"$SUBVOLUME" "$WORKING_DIR"/"$SUBVOLUME"-WEEKLY
	refresh_lists
}

process_days()
{
	local i
	#loop to determine if we even need a daily snapshot of this subvolume
	for i in ${DAILY_LIST[*]}
	do
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $1 $2 $3}') -eq $SUB_YEAR$SUB_MONTH$SUB_DAY ]]
		then
#			echo "They match! Already have a DAILY for this DAY."
			return 0 #exit this function as we already have a DAILY for this subvolume DAY
		fi		
	done
	echo -e "Creating DAILY snapshot: $SUBVOLUME-DAILY"
	#loop to determine if any HOURLY snapshots are older than current subvolume, if so then use them to create the DAILY
	for i in ${HOURLY_LIST[*]}
	do
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $3}') -eq "$SUB_DAY" && $(echo ${i#$BASENAME} | awk -F'-' '{printf substr($4,1,2)}') -le $SUB_HOUR ]]
		then
			#cp -r "$WORKING_DIR"/"$i" "$WORKING_DIR"/"${i%-HOURLY}"-DAILY
			btrfs subvolume snapshot -r "$WORKING_DIR"/"$i" "$WORKING_DIR"/"${i%-HOURLY}"-DAILY
			refresh_lists
			return 0
		fi			
	done
	#cp -r "$WORKING_DIR"/"$SUBVOLUME" "$WORKING_DIR"/"$SUBVOLUME"-DAILY
        btrfs subvolume snapshot -r "$WORKING_DIR"/"$SUBVOLUME" "$WORKING_DIR"/"$SUBVOLUME"-DAILY
	refresh_lists
}

process_hours()
{
	local i
	#loop to determine if we even need an hourly snapshot of this subvolume
	for i in ${HOURLY_LIST[*]}
	do
#		echo -e "$i\n$SUB_HOUR"
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $1 $2 $3 substr($4,1,2)}') -eq $SUB_YEAR$SUB_MONTH$SUB_DAY$SUB_HOUR ]]
		then
#			echo "They match! Already have a HOURLY for this HOUR."
			return 0 #exit this function as we already have a HOURLY for this subvolume HOUR
		fi		
	done
	echo -e "Creating HOURLY snapshot: $SUBVOLUME-HOURLY"
	#cp -r "$WORKING_DIR"/"$SUBVOLUME" "$WORKING_DIR"/"$SUBVOLUME"-HOURLY
        btrfs subvolume snapshot -r "$WORKING_DIR"/"$SUBVOLUME" "$WORKING_DIR"/"$SUBVOLUME"-HOURLY
	refresh_lists
}

delete_snapshot() #Needs one argument ($1) to know what to delete
{
	echo -e "Deleting snapshot: $1"
	#rm -rf "$WORKING_DIR"/"$1"
	btrfs subvolume delete "$WORKING_DIR"/"$1"
}

prune_snapshots()
{
	local i
	for i in ${YEARLY_LIST[*]}
	do
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $1}') -le $CUTOFF_YEAR ]]
		then
			echo -e "Pruning snapshot: $i"
			#rm -rf "$WORKING_DIR"/"$i"
			btrfs subvolume delete "$WORKING_DIR"/"$i"
		fi
	done
	for i in ${MONTHLY_LIST[*]}
		do
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $1 $2}') -le $CUTOFF_MONTH ]]
		then
			echo -e "Pruning snapshot: $i"
			#rm -rf "$WORKING_DIR"/"$i"
			btrfs subvolume delete "$WORKING_DIR"/"$i"
		fi
	done
	for i in ${WEEKLY_LIST[*]}
	do
		if [[ $(date +%Y%W --date=$(echo ${i#$BASENAME} | awk -F'-' '{printf $1 $2 $3}')) -le $CUTOFF_WEEK ]]
		then
			echo -e "Pruning snapshot: $i"
			#rm -rf "$WORKING_DIR"/"$i"
			btrfs subvolume delete "$WORKING_DIR"/"$i"
		fi
	done
	for i in ${DAILY_LIST[*]}
	do
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $1 $2 $3}') -le $CUTOFF_DAY ]]
		then
			echo -e "Pruning snapshot: $i"
			#rm -rf "$WORKING_DIR"/"$i"
			btrfs subvolume delete "$WORKING_DIR"/"$i"
		fi
	done
	for i in ${HOURLY_LIST[*]}
	do
		if [[ $(echo ${i#$BASENAME} | awk -F'-' '{printf $1 $2 $3 substr($4,1,2)}') -le $CUTOFF_HOUR ]]
		then
			echo -e "Pruning snapshot: $i"
			#rm -rf "$WORKING_DIR"/"$i"
			btrfs subvolume delete "$WORKING_DIR"/"$i"
		fi
	done
}


#get the initial lists
refresh_lists 
#main loop through all new snapshots (minute snapshots)
for SUBVOLUME in ${BACKUP_LIST[*]}
do
	SUB_YEAR=`echo ${SUBVOLUME#$BASENAME} | awk -F'-' '{printf $1}'`
	SUB_MONTH=`echo ${SUBVOLUME#$BASENAME} | awk -F'-' '{printf $2}'`
	SUB_WEEK=$(date +%Y%W --date=$(echo ${SUBVOLUME#$BASENAME} | awk -F'-' '{printf $1 $2 $3}'))
	SUB_DAY=`echo ${SUBVOLUME#$BASENAME} | awk -F'-' '{printf $3}'`
	#SUB_WEEK=`date +%Y%W --date="$SUB_YEAR$SUB_MONTH$SUB_DAY"`
	SUB_HOUR=`echo ${SUBVOLUME#$BASENAME} | awk -F'-' '{printf substr($4,1,2)}'`
	SUB_MINUTE=`echo ${SUBVOLUME#$BASENAME} | awk -F'-' '{printf substr($4,3,2)}'`
#	echo -e "Subvolume: $SUBVOLUME\nSub_Year: $SUB_YEAR\nSub_Month: $SUB_MONTH\nSub_Day: $SUB_DAY\nSub_Hour: $SUB_HOUR"
#	sleep 5
	#mkdir $WORKING_DIR/temp/$SUBVOLUME  #for testing
	if [[ $SUB_YEAR -gt $CUTOFF_YEAR ]]
	then
		process_years
	fi
	if [[ $SUB_YEAR$SUB_MONTH -gt $CUTOFF_MONTH ]]
	then
		process_months
	fi
	if [[ $SUB_WEEK -gt $CUTOFF_WEEK ]]
	then
		process_weeks
	fi
	if [[  $SUB_YEAR$SUB_MONTH$SUB_DAY -gt $CUTOFF_DAY  ]]
	then
		process_days
	fi
	if [[ $SUB_YEAR$SUB_MONTH$SUB_DAY$SUB_HOUR -gt $CUTOFF_HOUR ]]
	then
		process_hours
	fi
	#clean up (remove) any snapshots older than RETENTION_MINUTES or remove if DELETE_IT set to 1
	if [[ $SUB_YEAR$SUB_MONTH$SUB_DAY$SUB_HOUR$SUB_MINUTE -lt $CUTOFF_MINUTE ]]
	then
		delete_snapshot $SUBVOLUME
	fi
done

#and finally, prune any snapshots that have passed their retention limit
prune_snapshots



