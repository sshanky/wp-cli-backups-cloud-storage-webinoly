#!/bin/bash
# Based on script by Mike from: https://guides.wp-bullet.com
# 20181202 updated for webinoly to handle output from 'site -list' command

#define local path for backups
BACKUPPATH="/path/to/gdrive-backup-tmp/folder"

#define remote backup path
BACKUPPATHREM="folder-name-on-gdrive"

#path to WordPress installations, no trailing slash
SITESTORE="/var/www"

#date prefix
DATEFORM=$(date +"%Y-%m-%d")

#Days to retain
DAYSKEEP=14

#calculate days as filename prefix
DAYSKEPT=$(date +"%Y-%m-%d" -d "-$DAYSKEEP days")

#create array of sites based on folder names
echo Generating site list

# webinoly site -list command returns lines that start with hyphens and spaces, along with control chars, which need to be removed
# SED s/[\x01-\x1F\x7F]//g removes control characters
# SED s/.{7}// removes first seven chars and s/.{5}$// removes last 5 chars
# SED /^\s*$/d removes blank lines
# removing characters http://www.theunixschool.com/2014/08/sed-examples-remove-delete-chars-from-line-file.html
# removing empty lines https://stackoverflow.com/questions/16414410/delete-empty-lines-using-sed
SITELIST=($(/usr/bin/site -list | sed -r "s/[\x01-\x1F\x7F]//g;s/.{7}//;s/.{5}$//;/^\s*$/d"))
#print site list
echo Site list
echo ---
for SITE in ${SITELIST[@]}; do
echo "$SITE"
done
echo ---
#make sure the backup folder exists
mkdir -p $BACKUPPATH

#check remote backup folder exists on gdrive
BACKUPSID=$(gdrive list --no-header | grep $BACKUPPATHREM | grep dir | awk '{ print $1}')
    if [ -z "$BACKUPSID" ]; then
        gdrive mkdir $BACKUPPATHREM
        BACKUPSID=$(gdrive list --no-header | grep $BACKUPPATHREM | grep dir | awk '{ print $1}')
    fi

#start the loop
echo Starting
for SITE in ${SITELIST[@]}; do
    echo ----------
    echo Working on $SITE
    #delete old backup, get folder id and delete if exists
    OLDBACKUP=$(gdrive list --no-header | grep $DAYSKEPT-$SITE | grep dir | awk '{ print $1}')
    if [ ! -z "$OLDBACKUP" ]; then
        gdrive delete $OLDBACKUP
    fi

    # create the local backup folder if it doesn't exist
    if [ ! -e $BACKUPPATH/$SITE ]; then
        mkdir $BACKUPPATH/$SITE
    fi

    #enter the WordPress folder
    #added "htdocs" per ee structure
    cd $SITESTORE/$SITE/htdocs

    #back up the WordPress folder
    #tar -czf $BACKUPPATH/$SITENAME/$SITE/$DATEFORM-$SITE.tar.gz .
    zip -r --quiet $BACKUPPATH/$SITENAME/$SITE/$DATEFORM-$SITE.zip .
    #back up the WordPress database, compress and clean up
    wp db export $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql --all-tablespaces --single-transaction --quick --lock-tables=false --allow-root --skip-themes --skip-plugins
    #cat $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql | gzip > $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql.gz
    cat $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql | zip > $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql.zip
    rm $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql

    #get current folder ID
    SITEFOLDERID=$(gdrive list --no-header | grep $SITE | grep dir | awk '{ print $1}')

    #create folder if doesn't exist
    if [ -z "$SITEFOLDERID" ]; then
        gdrive mkdir --parent $BACKUPSID $SITE
        SITEFOLDERID=$(gdrive list --no-header | grep $SITE | grep dir | awk '{ print $1}')
    fi

    #upload WordPress tar
    #gdrive upload --parent $SITEFOLDERID --delete $BACKUPPATH/$SITE/$DATEFORM-$SITE.tar.gz
    gdrive upload --parent $SITEFOLDERID --delete $BACKUPPATH/$SITE/$DATEFORM-$SITE.zip
    #upload wordpress database
    #gdrive upload --parent $SITEFOLDERID --delete $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql.gz
    gdrive upload --parent $SITEFOLDERID --delete $BACKUPPATH/$SITE/$DATEFORM-$SITE.sql.zip

done

#Fix permissions
sudo chown -R www-data:www-data $SITESTORE
sudo find $SITESTORE -type f -exec chmod 644 {} +
sudo find $SITESTORE -type d -exec chmod 755 {} +
