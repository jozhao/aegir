#
# This Dockerfile sets up an Aegir "remote server" using Apache
#
# Pandastix studio 2016
#

# docker run --env AUTHORIZED_KEYS='aegir server master ssh key'

################## INIT DOCKER INSTALLATION ######################

FROM ubuntu:trusty
MAINTAINER Joseph Zhao <joseph.zhao@pandastix.com>

# Set up ENV
ENV DEBIAN_FRONTEND noninteractive

ENV MYSQL_MAJOR 5.5
ENV MYSQL_USER mysql
ENV MYSQL_ROOT_PASSWORD root
ENV MYSQL_DATADIR /var/lib/mysql

ENV AEGIR_VERSION 7.x-3.2
ENV AEGIR_DB_PASSWORD password

# Configure no init scripts to run on package updates.
ADD src/policy-rc.d /usr/sbin/policy-rc.d

################## BEGIN INSTALLATION ######################

# OS update and upgrade
RUN apt-get update -y && apt-get dist-upgrade -y
RUN apt-get autoclean
RUN apt-get install -y supervisor openssl htop curl wget postfix sudo rsync git-core unzip nano

# Install aegir required packages
RUN apt-get -y install apache2 php5 php5-cli php5-gd php5-mcrypt php5-mysql php-pear

# Configure apache
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf
RUN a2dismod mpm_event && a2enmod mpm_prefork && a2enmod rewrite

# Install MySQL
# set installation parameters to prevent the installation script from asking
RUN { \
		echo "mysql-server-5.5 mysql-server/root_password password $MYSQL_ROOT_PASSWORD"; \
		echo "mysql-server-5.5 mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"; \
	} | debconf-set-selections \
	&& apt-get update && apt-get install -y mysql-server

# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container
RUN sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/my.cnf \
	&& echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/my.cnf > /tmp/my.cnf \
	&& mv /tmp/my.cnf /etc/mysql/my.cnf

# Setup aegir user
RUN adduser --system --group --home /var/aegir aegir
RUN adduser aegir www-data  
RUN echo 'aegir ALL=NOPASSWD: /usr/sbin/apache2ctl' >> /etc/sudoers.d/aegir

# Configure Aegir apache
RUN ln -s /var/aegir/config/apache.conf /etc/apache2/conf-enabled/aegir.conf

# Aegir user commands
RUN mkdir /var/aegir/.ssh
RUN mkdir /var/aegir/config
RUN chmod 600 /var/aegir/.ssh
RUN chown -R aegir:aegir /var/aegir

# Install DRUSH
RUN wget http://files.drush.org/drush.phar
RUN chmod +x drush.phar
RUN sudo mv drush.phar /usr/local/bin/drush
RUN drush init

##################### ADD SUPPORT FILES #####################

ADD src/pandastix_docker_apache.sh /pandastix_docker_apache.sh
ADD src/pandastix_docker_mysql.sh /pandastix_docker_mysql.sh
# Add aegir db user
ADD src/pandastix_docker_aegir_db.sh /pandastix_docker_aegir_db.sh
ADD src/pandastix_docker_supervisor.conf /etc/supervisor/conf.d/pandastix_docker_supervisor.conf
ADD src/pandastix_docker_run.sh /pandastix_docker_run.sh

# Give the execution permissions
RUN chmod +x /*.sh

##################### INSTALLATION END #####################

# Add volumes
VOLUME ["/var/aegir","/var/log/apache2", "/var/lib/mysql", "/etc/mysql/conf.d", "/var/log/mysql"]

# Expose port
EXPOSE 22
EXPOSE 80
EXPOSE 443
EXPOSE 3306

# Execut the pandastix_docker_run.sh
CMD ["/pandastix_docker_run.sh"]