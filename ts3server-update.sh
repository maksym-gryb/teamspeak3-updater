#!/bin/bash
# TeamSpeak3 Server Updater - Unofficial
# version 1.0

# CONSTANTS
TS3SERVER_ZIP=/tmp/ts3server-new.tar.bz2
TS3SERVER_UNZIP=/tmp/teamspeak3-server_linux_amd64

TS3_BACKUP_DIR=`mktemp -d`
TS3SERVER_DIR=/opt/teamspeak3-server
SHA256SUM_FILE=$TS3SERVER_DIR/sha256sum

FULL_BACKUP_DIR=/opt/ts3server.backup

backup_required='true'

# verify if new version is available by comparing checksums
sha256sum=`curl https://www.teamspeak.com/en/downloads | grep -i 'class="checksum"' | sed -n '9p' | cut -d: -f2 | cut -d\< -f1 | tr -d ' \n'`
if [ -a $SHA256SUM_FILE ]
then
        if [ $sha256sum == $(cat $SHA256SUM_FILE) ]
        then
                echo "No new version available"
                exit
        fi
else
        if [ ! -d $TS3SERVER_DIR ]
		then
                backup_required='false'
        fi
fi
echo $sha256sum > $SHA256SUM_FILE

# Download TS3Server
cd /tmp
url=`curl https://www.teamspeak.com/en/downloads | grep 'id="clipboard' | grep teamspeak3-server_linux_amd64 | sed -n 's/.* data-clipboard-text="\([^"]\+\).*/\1/p' | tr -d ' \n'`
wget -O $TS3SERVER_ZIP $url
if [ $(sha256sum $TS3SERVER_ZIP | cut -d' ' -f1) != $(cat $SHA256SUM_FILE) ]
then
        echo "ERROR: checksum does not match .zip file"
        exit
fi
tar -xjf $TS3SERVER_ZIP

# Stop Current Process
kill $(pidof ts3server)
rm $TS3SERVER_DIR/ts3server.pid

# Backup configs
if [ $backup_required == 'true' ]
then
        cp $TS3SERVER_DIR/*.ini $TS3SERVER_DIR/*.dat $TS3SERVER_DIR/*.sqlitedb $TS3SERVER_DIR/files -t $TS3_BACKUP_DIR > /dev/null 2>&1
fi

# Backup teamspeak3-server in case the script messes everything up
mkdir -p $FULL_BACKUP_DIR
tar -cvpzf $FULL_BACKUP_DIR/teamspeak3-server-backup-$(date +%F).tar.gz $TS3SERVER_DIR

# Update to new version
rm -rf $TS3SERVER_DIR/*
mv $TS3SERVER_UNZIP/* $TS3SERVER_DIR/
echo $sha256sum > $SHA256SUM_FILE

# Restore configs
if [ $backup_required == 'true' ]
then
        mv $TS3_BACKUP_DIR/*.ini $TS3_BACKUP_DIR/*.dat $TS3_BACKUP_DIR/*.sqlitedb $TS3_BACKUP_DIR/files -t $TS3SERVER_DIR > /dev/null 2>&1
fi

# Start TeamSpeak Server
cd $TS3SERVER_DIR
chown -R teamspeak3-user:teamspeak3-user $TS3SERVER_DIR
#./ts3server_linux_amd64 inifile=ts3server.ini > /dev/null 2>&1 & # for testing only
if [ "$#" -gt "1" ]
then
	if [ "$2" -eq "norun" ]
	then
		echo "[?] Run TeamSpeak3 Server manually"
	else
		/etc/init.d/ts3 start
	fi
fi
#./ts3server_startscript.sh start # for testing only