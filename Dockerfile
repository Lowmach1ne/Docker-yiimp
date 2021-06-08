FROM amd64/almalinux:latest
MAINTAINER Lowmach1ne
ARG REPOSITORY=https://github.com/tpruvot/yiimp.git

# Enabled systemd
ENV container docker

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

# Volume
#VOLUME [ "/sys/fs/cgroup" ]

# copy root
COPY rootfs/ /

# updates os
RUN dnf upgrade -y

# install git
RUN dnf install git -y

# Download yiimp
RUN git clone --progress ${REPOSITORY} ~/yiimp
RUN make -C ~/yiimp/stratum/iniparser
RUN make -C ~/yiimp/stratum
RUN mkdir -p /var/stratum/config
RUN cp ~/yiimp/stratum/run.sh /var/stratum
RUN cp ~/yiimp/stratum/config/run.sh /var/stratum/config
RUN cp ~/yiimp/stratum/stratum /var/stratum
RUN cp ~/yiimp/stratum/config.sample/neo.conf /var/stratum/config
#RUN rm -rf ~/yiimp

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

# install php
RUN dnf install php-fpm
#RUN systemctl enable php-fpm

# install mysql
RUN dnf install mariadb -y

WORKDIR /var/stratum

# End
CMD ["bash", "run.sh", "neo.conf"]

#EXPOSE 4233
