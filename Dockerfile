FROM amd64/almalinux:latest
MAINTAINER Lowmach1ne
ENV server_name=yiimp.test.com
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

# Set timezone
RUN timedatectl set-timezone America/Toronto

# uninstall dev tools
RUN dnf group remove "Development Tools" -y

# install fail2ban
RUN dnf install fail2ban -y

# Web setup
RUN mkdir -p /var/www/$server_name/html
RUN echo -e 'include /etc/nginx/blockuseragents.rules; \n\
server { \n\
if ($blockedagent) { \n\
            return 403; \n\
    } \n\
    if ($request_method !~ ^(GET|HEAD|POST)$) { \n\
    return 444; \n\
    } \n\
    listen 80; \n\
    listen [::]:80; \n\
    server_name '"${server_name}"'; \n\
    root "/var/www/'"${server_name}"'/html/web"; \n\
    index index.html index.htm index.php; \n\
    charset utf-8; \n\
\n\
    location / { \n\
    try_files $uri $uri/ /index.php?$args; \n\
    } \n\
    location @rewrite { \n\
    rewrite ^/(.*)$ /index.php?r=$1; \n\
    } \n\
\n\
    location = /favicon.ico { access_log off; log_not_found off; } \n\
    location = /robots.txt  { access_log off; log_not_found off; } \n\
\n\
    access_log /var/log/nginx/'"${server_name}"'.app-access.log; \n\
    error_log /var/log/nginx/'"${server_name}"'.app-error.log; \n\
\n\
    # allow larger file uploads and longer script runtimes \n\
    client_body_buffer_size  50k; \n\
    client_header_buffer_size 50k; \n\
    client_max_body_size 50k; \n\
    large_client_header_buffers 2 50k; \n\
    sendfile off; \n\
\n\
    location ~ ^/index\.php$ { \n\
        fastcgi_split_path_info ^(.+\.php)(/.+)$; \n\
        fastcgi_pass unix:/var/run/php/php7.3-fpm.sock; \n\
        fastcgi_index index.php; \n\
        include fastcgi_params; \n\
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; \n\
        fastcgi_intercept_errors off; \n\
        fastcgi_buffer_size 16k; \n\
        fastcgi_buffers 4 16k; \n\
        fastcgi_connect_timeout 300; \n\
        fastcgi_send_timeout 300; \n\
        fastcgi_read_timeout 300; \n\
    try_files $uri $uri/ =404; \n\
    } \n\
    location ~ \.php$ { \n\
        return 404; \n\
    } \n\
    location ~ \.sh { \n\
    return 404; \n\
    } \n\
    location ~ /\.ht { \n\
    deny all; \n\
    } \n\
    location ~ /.well-known { \n\
    allow all; \n\
    } \n\
    location /phpmyadmin { \n\
    root /usr/share/; \n\
    index index.php; \n\
    try_files $uri $uri/ =404; \n\
    location ~ ^/phpmyadmin/(doc|sql|setup)/ { \n\
        deny all; \n\
  } \n\
    location ~ /phpmyadmin/(.+\.php)$ { \n\
        fastcgi_pass unix:/run/php/php-fpm.sock; \n\
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; \n\
        include fastcgi_params; \n\
        include snippets/fastcgi-php.conf; \n\
    } \n\
  } \n\
} \n\ ' | tee /etc/nginx/sites-available/$server_name.conf >/dev/null 2>&1
RUN ln -s /etc/nginx/sites-available/$server_name.conf /etc/nginx/sites-enabled/$server_name.conf
RUN ln -s /var/web /var/www/$server_name/html

WORKDIR /var/stratum

# End
CMD ["bash", "run.sh", "neo.conf"]

#EXPOSE 4233
