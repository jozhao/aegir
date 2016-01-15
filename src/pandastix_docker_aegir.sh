#!/bin/sh

GRANT="GRANT ALL PRIVILEGES ON *.* TO 'aegir_root'@'%' IDENTIFIED BY '${AEGIR_DB_PASSWORD}' WITH GRANT OPTION;\
	       FLUSH PRIVILEGES;"
echo "$GRANT" | mysql -u root -h localhost -p$MYSQL_ROOT_PASSWORD

su -s /bin/bash - aegir

if drush help | grep "^ provision-install" > /dev/null ; then
	echo "INFO: Provision already seems to be installed"
else 
	echo "INFO: Download Aegir Provision"
	drush dl --destination=/var/aegir/.drush provision-$AEGIR_VERSION
	drush cache-clear drush
fi

if [ -e "/var/aegir/.drush/hostmaster.alias.drushrc.php" ] ; then
	echo "INFO: Hostmaster already installed"
else 
	echo "INFO: Install Aegir Provision"
	OPTIONS="--yes --debug --aegir_host=$AEGIR_SITE --aegir_db_host=localhost --aegir_db_user=aegir_root --aegir_db_pass=$AEGIR_DB_PASSWORD --version=$AEGIR_VERSION  --client_email=$AEGIR_EMAIL --script_user=aegir --http_service_type=apache $AEGIR_FRONTEND_URL"
	echo $OPTIONS
	drush -dv hostmaster-install $OPTIONS
fi
