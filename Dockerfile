FROM amd64/almalinux:latest
MAINTAINER Lowmach1ne
ARG server_name=yiimp.test.com
ARG REPOSITORY=https://github.com/tpruvot/yiimp.git

# Enabled systemd
ENV container docker

# Add repo
RUN dnf install epel-release -y
RUN dnf install https://rpms.remirepo.net/enterprise/remi-release-8.rpm -y
RUN dnf install dnf-plugins-core -y
RUN dnf config-manager --set-enabled powertools

# updates os
RUN dnf upgrade -y

# Replace systemctl
COPY systemctl.py /usr/bin/systemctl

# install git
RUN dnf install git -y

# install dev tools
RUN dnf group install "Development Tools" -y
RUN dnf install gmp gmp-devel -y
RUN dnf install mariadb-devel -y
RUN dnf install libcurl-devel -y
RUN dnf install libidn2-devel -y
RUN dnf install libssh-devel -y
RUN dnf install brotli-devel -y
RUN dnf install openldap-devel -y
RUN dnf install libnghttp2-devel -y
RUN dnf install libpsl-devel -y

# crontab
RUN dnf install -y cronie
RUN (crontab -l 2>/dev/null; echo "* * * * * /usr/bin/verify-external-ip.sh") | crontab -

# install screen
RUN dnf install screen -y

# install nginx
RUN dnf install -y nginx
RUN systemctl enable nginx

# install memcached
RUN dnf install -y memcached
RUN systemctl enable memcached

# install lib ruby
RUN dnf install ruby-libs -y

# install libmcrypt
RUN dnf install libmcrypt -y

# install php
RUN dnf module reset php -y
RUN dnf module install php:remi-8.0 -y
RUN dnf install php-fpm php-opcache php php-common php-gd php-mysql php-imap php-cli \
    php-cgi php-pear ImageMagick php-curl php-intl php-pspell php-mcrypt\
    php-sqlite3 php-tidy php-xmlrpc php-xsl php-memcache php-imagick php-gettext php-zip php-mbstring -y
RUN systemctl enable php-fpm

# install mysql
RUN dnf install mariadb -y

# Generating Random Password for stratum
RUN blckntifypass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`

# Download yiimp
RUN git clone --progress ${REPOSITORY} /root/yiimp

# Compile blocknotify
WORKDIR /root/yiimp/blocknotify
RUN sed -i 's/tu8tu5/'$blckntifypass'/' blocknotify.cpp
RUN make

# Compile iniparser
WORKDIR /root/yiimp/stratum/iniparser
RUN make

# Compile stratum
WORKDIR /root/yiimp/stratum
RUN sed -i 's/CFLAGS += -DNO_EXCHANGE/#CFLAGS += -DNO_EXCHANGE/' /root/yiimp/stratum/Makefile # enable BTC
RUN make

# Copy Files (Blocknotify,iniparser,Stratum)
WORKDIR /root/yiimp
RUN sed -i 's/AdminRights/'AdminPanel'/' /root/yiimp/web/yaamp/modules/site/SiteController.php
RUN cp -r ~/yiimp/web /var/
RUN mkdir -p /var/stratum
WORKDIR /root/yiimp/stratum
RUN cp -a config.sample/. /var/stratum/config
RUN cp -r stratum /var/stratum
RUN cp -r run.sh /var/stratum
WORKDIR /root/yiimp
RUN cp -r /root/yiimp/bin/. /bin/
RUN cp -r /root/yiimp/blocknotify/blocknotify /usr/bin/
RUN cp -r /root/yiimp/blocknotify/blocknotify /var/stratum/
RUN mkdir -p /etc/yiimp
RUN mkdir -p /root/backup/

# fixing yiimp
RUN sed -i "s|ROOTDIR=/data/yiimp|ROOTDIR=/var|g" /bin/yiimp

# fixing run.sh
RUN rm -r /var/stratum/config/run.sh
RUN echo -e '#!/bin/bash \n\
ulimit -n 10240 \n\
ulimit -u 10240 \n\
cd /var/stratum \n\
while true; do \n\
./stratum /var/stratum/config/$1 \n\
sleep 2 \n\
done \n\
exec bash \n\
' | tee /var/stratum/config/run.sh >/dev/null 2>&1
RUN chmod +x /var/stratum/config/run.sh

# deploy screen-scrypt
RUN echo -e '#!/bin/bash\n\
LOG_DIR=/var/log/yiimp\n\
WEB_DIR=/var/web\n\
STRATUM_DIR=/var/stratum\n\
USR_BIN=/usr/bin\n\
\n\
screen -dmS main bash $WEB_DIR/main.sh\n\
screen -dmS loop2 bash $WEB_DIR/loop2.sh\n\
screen -dmS blocks bash $WEB_DIR/blocks.sh\n\
screen -dmS debug tail -f $LOG_DIR/debug.log\n\
' | tee /etc/screen-scrypt.sh >/dev/null 2>&1
RUN chmod +x /etc/screen-scrypt.sh

# Set timezone
RUN ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime

# uninstall dev tools
RUN dnf group remove "Development Tools" -y

# install fail2ban
RUN dnf install fail2ban -y

WORKDIR /var/stratum

# End
ENTRYPOINT ["/usr/sbin/init"]
#CMD ["bash", "run.sh", "neo.conf"]

#EXPOSE 4233
