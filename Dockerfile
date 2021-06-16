FROM amd64/almalinux:latest
MAINTAINER Lowmach1ne
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
#RUN (crontab -l 2>/dev/null; echo "* * * * * /usr/bin/verify-external-ip.sh") | crontab -

# install screen
RUN dnf install screen -y

# install nginx
RUN dnf install -y nginx
#RUN systemctl enable nginx

# install memcached
RUN dnf install -y memcached
#RUN systemctl enable memcached

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
#RUN systemctl enable php-fpm

# install mysql
RUN dnf install mariadb -y

# Generating Random Password for stratum
RUN blckntifypass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`

# Download yiimp
RUN git clone --progress ${REPOSITORY} ~/yiimp

# Compile blocknotify
RUN cd ~/yiimp/blocknotify
RUN sed -i 's/tu8tu5/'$blckntifypass'/' blocknotify.cpp
RUN make

# Compile stratum
RUN cd ~/yiimp/stratum
RUN sed -i 's/CFLAGS += -DNO_EXCHANGE/#CFLAGS += -DNO_EXCHANGE/' ~/yiimp/stratum/Makefile # enable BTC
RUN make

# Compile iniparser
RUN cd ~/yiimp/stratum/iniparser
RUN make

# Copy Files (Blocknotify,iniparser,Stratum)
RUN cd ~/yiimp
RUN sed -i 's/AdminRights/'AdminPanel'/' ~/yiimp/web/yaamp/modules/site/SiteController.php
RUN cp -r ~/yiimp/web /var/
RUN mkdir -p /var/stratum
RUN cd ~/yiimp/stratum
RUN cp -a config.sample/. /var/stratum/config
RUN cp -r stratum /var/stratum
RUN cp -r run.sh /var/stratum
RUN cd ~/yiimp
RUN cp -r ~/yiimp/bin/. /bin/
RUN cp -r ~/yiimp/blocknotify/blocknotify /usr/bin/
RUN cp -r ~/yiimp/blocknotify/blocknotify /var/stratum/
RUN mkdir -p /etc/yiimp
RUN mkdir -p ~/backup/

# fixing yiimp
RUN sed -i "s|ROOTDIR=/data/yiimp|ROOTDIR=/var|g" /bin/yiimp

# fixing run.sh
RUN rm -r /var/stratum/config/run.sh
RUN echo '
    #!/bin/bash
    ulimit -n 10240
    ulimit -u 10240
    cd /var/stratum
    while true; do
    ./stratum /var/stratum/config/$1
    sleep 2
    done
    exec bash
    ' | sudo -E tee /var/stratum/config/run.sh >/dev/null 2>&1
RUN chmod +x /var/stratum/config/run.sh

# uninstall dev tools
RUN dnf group remove "Development Tools" -y

WORKDIR /var/stratum

# End
CMD ["bash", "run.sh", "neo.conf"]

#EXPOSE 4233
