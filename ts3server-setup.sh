#!/bin/bash
# TeamSpeak3 Server Setup - Unofficial
# version 0.1

required_packages="mariadb-client mariadb-server libmariadb2"

ts3_user="teamspeak3-user"
initd_script_location=/etc/init.d/ts3

ts3_server_dir=/opt/teamspeak3-server

echo "[*] Installing dependencies"
apt install -y $required_packages

echo "[*] Securing MariaDB"
sql_root_password=""
sql_root_password_again="empty"
while [ sql_root_password != sql_root_password_again ]
do
	echo -n "MariaDB root password:"
	read -e -s sql_root_password
	echo -n "MariaDB root password again:"
	read -e -s sql_root_password_again
	
	if [ sql_root_password != sql_root_password_again ]
	then
		echo "[X] ERROR: passwords do not match"
	fi
done

mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('$sql_root_password') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;

CREATE database teamspeak3;
GRANT ALL PRIVILEGES ON teamspeak3.* TO teamspeak3@localhost IDENTIFIED BY 'PASSWORD';
FLUSH privileges;
EOF

if id $ts3_user &>/dev/null;
then
	echo "[-] User $ts3_user already exists"
else
	echo "[*] Creating user $ts3_user"
	useradd -d $ts3_server_dir -m $ts3_user	
fi

if [ -a '/etc/sudoers' ]
then
	echo "[*] Adding required sudoer privilege for $ts3_user"
	echo "$ts3_user ALL = (root) NOPASSWD: $initd_script_location" >> /etc/sudoers
else
	echo "[X] ERROR: sudo not installed (could not find /etc/sudoers)"
	exit 0
fi

echo "[*] Creating init.d script for teamspeak3-server in $initd_script_location"
cat << EOT > $initd_script_location
#! /bin/sh
### BEGIN INIT INFO
# Provides:          ts3
# Required-Start:    $network mysql
# Required-Stop:     $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: TeamSpeak3 Server Daemon
# Description:       Starts/Stops/Restarts the TeamSpeak Server Daemon
### END INIT INFO

set -e

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DESC="TeamSpeak3 Server"
NAME=teamspeak3-server
USER=teamspeak3-user
DIR=/opt/teamspeak3-server
OPTIONS=inifile=ts3server.ini
DAEMON=$DIR/ts3server_startscript.sh
#PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

# Gracefully exit if the package has been removed.
test -x $DAEMON || exit 0

sleep 2
EOT

chmod a+x /etc/init.d/ts3
chmod a+x /opt/teamspeak3-server/ts3server_startscript.sh
chmod a+x /opt/teamspeak3-server/ts3server_minimal_runscript.sh
update-rc.d ts3 defaults

./ts3-updater.sh norun

# wget http://dl.4players.de/ts/releases/3.0.11.4/teamspeak3-server_linux-amd64-3.0.11.4.tar.gz
# tar -zxvf teamspeak3-server_linux-amd64-3.0.11.4.tar.gz
# mv teamspeak3-server_linux-amd64/* /opt/teamspeak3-server
# chown teamspeak3-user:teamspeak3-user /opt/teamspeak3-server -R
# rm -fr teamspeak3-server_linux-amd64-3.0.11.4.tar.gz teamspeak3-server_linux-amd64

ln -s /opt/teamspeak3-server/redist/libmariadb.so.2 /opt/teamspeak3-server/libmariadb.so.2
ldd /opt/teamspeak3-server/libts3db_mariadb.so


echo "[*] Configuring TeamSpeak"
touch /opt/teamspeak3-server/query_ip_blacklist.txt

cat  << EOT > /opt/teamspeak3-server/query_ip_whitelist.txt
127.0.0.1
EOT

cat  << EOT > /opt/teamspeak3-server/ts3server.ini
machine_id=
default_voice_port=9987
voice_ip=0.0.0.0
licensepath=
filetransfer_port=30033
filetransfer_ip=0.0.0.0
query_port=10011
query_ip=0.0.0.0
query_ip_whitelist=query_ip_whitelist.txt
query_ip_blacklist=query_ip_blacklist.txt
dbsqlpath=sql/
dbplugin=ts3db_mariadb
dbsqlcreatepath=create_mariadb/
dbpluginparameter=ts3db_mariadb.ini
dbconnections=10
logpath=logs
logquerycommands=0
dbclientkeepdays=30
logappend=0
query_skipbruteforcecheck=0
EOT

cat  << EOT > /opt/teamspeak3-server/ts3server.ini
[config]
host=127.0.0.1
port=3306
username=teamspeak3
password=PASSWORD
database=teamspeak3
socket=
EOT


