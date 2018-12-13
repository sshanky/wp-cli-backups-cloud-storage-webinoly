#!/bin/bash
# Source: https://guides.wp-bullet.com
# Author: Mike
# heavily updated to work with Webinoly
# 20181202 updated for webinoly because 'site -list' returns " - " before each site
# 20181212 removed existing site list mechanism and used Webinoly's own site code, other minor tweaks

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

# Site list taken from Webinoly Site Manager Plugin (Create, delete and de/activate) at /usr/bin/site
# webinoly must be installed
source /opt/webinoly/lib/sites

# Generate array of sites (using part of List Sites command in webinoly)
	for site in "/etc/nginx/sites-available"/*
	do
		domi=$(echo $site | cut -f 5 -d "/")
		[[ -a /var/www/$domi ]] && sign="${gre} -" || sign="${blu} *${gre}"
		[[ $domi != "default" && $domi != $(conf_read tools-port) ]] && SITELIST+="$domi "
	done

#print site list
echo Site list
echo ----------
for SITE in ${SITELIST[@]}; do
echo "$SITE"
done
echo ----------

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
    #added "htdocs" per ee/webinoly structure
    cd $SITESTORE/$SITE/htdocs
  
    #back up the WordPress folder
    echo Compressing $SITE
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

