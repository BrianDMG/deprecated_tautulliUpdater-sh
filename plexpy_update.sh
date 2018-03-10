#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

#This script will update your Tautulli install to the latest version from GitHub

#-----------------------------------------------------------------------------------------------------------------------------------------------
#User-defined variables
	#Local Tautulli directory
	TAUTDIR=/usr/local/plexpy
	#Backup directory
	BACKUPDIR=/usr/local/plexpy_bk
	#Tautulli IP or hostname
	TAUTHOST=
	TAUTAPIKEY=''
	#Tautulli protocol (http or https)
	TAUTPROTO="https"
	#PlexyPy port
	TAUTPORT="8181"
#SSMTP variables
	#To address
	TO="example@example.com"
	#From adderess
	FROM="example@example.com"
	#Subject
	SUBJECT="Tautulli Server Updated"
	#Body
	BODY="<html><head><meta charset="UTF-8" /></head><body>Tautulli has been updated to <strong>$LOCALVER</strong>.<br><a href=https://github.com/JonnyWong16/plexpy/releases/tag/v$LOCALVER target=_blank>Release notes</a></body></html>"
#-----------------------------------------------------------------------------------------------------------------------------------------------

#Get local Plexpy version, convert to raw int for mathematical comparison, set as $LOCALVER and $LOCALVERCOMP
LOCALVER=$(cat $TAUTDIR/plexpy/version.py | grep PLEXPY_RELEASE_VERSION | sed -r 's/\"//g' | sed -r 's/\PLEXPY_RELEASE_VERSION = //g')
LOCALVERCOMP=$(cat $TAUTDIR/plexpy/version.py | grep PLEXPY_RELEASE_VERSION | sed -r 's/\"//g' | sed -r 's/\PLEXPY_RELEASE_VERSION = //g' | sed -r 's/\.//g')

#Scrape Github for latest release tag info, strip all but the numbers for mathematical comparison
REMOTEVER=$(curl -s https://api.github.com/repositories/31169720/releases/latest | jq '.tag_name' | sed 's/"//g' | sed -r 's/v//g')
REMOTEVERCOMP=$(curl -s https://api.github.com/repositories/31169720/releases/latest | jq '.tag_name' | sed 's/"//g' | sed -r 's/v//g' | sed -r 's/\.//g')

#Compare LOCALVER and REMOTEVER
	#If the remote version is higher than the local version, update
	if [ $REMOTEVERCOMP -gt $LOCALVERCOMP ] 
	then
		#Download latest release to /tmp
		(cd /tmp; wget https://github.com/Tautulli/Tautulli/archive/v$REMOTEVER.zip)
		
		#Unzip Tautulli release .zip to /tmp
		unzip /tmp/v$REMOTEVER.zip
		rm -f /tmp/v$REMOTEVER.zip
		
		#Stop Tautulli
		#killall -15 screen
		GETPID=$(pgrep py || true)
		if [ -e "$GETPID" ]
		then
			#Clear cache before stopping
			curl -k "$TAUTPROTO://$TAUTHOST:$TAUTPORT/api/v2?apikey=$TAUTAPIKEY&cmd=delete_cache"
			kill -15 $GETPID
			sleep 5
		fi

		#Backup existing Tautulli directory
		mkdir -p "$BACKUPDIR"
		cp -rf "$TAUTDIR/" "$BACKUPDIR/"
		rm -rf "$TAUTDIR/*"

		#Overwrite old Tautulli install
		cp -rf /tmp/Tautulli-$REMOTEVER/ $TAUTDIR/
		rm -rf /tmp/Tautulli*
		cp $BACKUPDIR/config.ini $TAUTDIR/
		cp $BACKUPDIR/plexpy.db $TAUTDIR/
		cp $BACKUPDIR/GeoLite2-City.mmdb $TAUTDIR/
		
		#Start Tautulli
		SCREENPATH=$(which screen)
		PYTHON2PATH=$(which python2)
		$SCREENPATH -d -m -S root nohup $PYTHON2PATH $TAUTDIR/Tautulli.py

		#Use sendmail/ssmtp to send email to post to Wordpress
		( 
		echo "From: $FROM"
		echo "To: $TO"
		echo "MIME-Version: 1.0"
		echo "Content-Type: text/html"
		echo "Subject: $SUBJECT"
		echo "$BODY"
		) | sendmail -f $FROM $TO
		
		#Otherwise, exit.
	else
		echo "Already on the latest release ($LOCALVER)"
	fi
exit
