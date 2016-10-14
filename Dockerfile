FROM netivism/docker-jessie-mariadb 
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

ENV \
  APACHE_RUN_USER=www-data \
  APACHE_RUN_GROUP=www-data \
  APACHE_LOG_DIR=/var/log/apache2 \
  APACHE_LOCK_DIR=/var/lock/apache2 \
  APACHE_PID_FILE=/var/run/apache2.pid \
  COMPOSER_HOME=/root/.composer \
  PATH=/root/.composer/vendor/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /etc/apt/sources.list.d
RUN echo "deb http://packages.dotdeb.org jessie all" > dotdeb.list \
    && echo "deb-src http://packages.dotdeb.org jessie all" >> dotdeb.list \
    && apt-get update && apt-get install -y wget && wget http://www.dotdeb.org/dotdeb.gpg \
    && apt-key add dotdeb.gpg && \
    rm -f dotdeb.gpg

WORKDIR /
RUN \
  apt-get update && \
  apt-get install -y \
    rsyslog \
    php7.0 \
    php7.0-curl \
    php7.0-gd \
    php7.0-mcrypt \
    php7.0-mysql \
    php7.0-memcached \
    php7.0-cli \
    php7.0-fpm \
    curl \
    vim \
    git-core

RUN \
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
  composer global require drush/drush:8.1.5 && \
  git clone https://github.com/NETivism/docker-sh.git /home/docker && \
  cd /root/.composer && \
  find . | grep .git | xargs rm -rf && \
  rm -rf /root/.composer/cache/*

### PHP FPM Config
# remove default enabled site
RUN \
  mkdir -p /var/www/html/log/supervisor && \
  cp -f /home/docker/php/default55.ini /etc/php/7.0/docker_setup.ini && \
  ln -s /etc/php/7.0/docker_setup.ini /etc/php/7.0/fpm/conf.d/ && \
  cp -f /home/docker/php/default55_cli.ini /etc/php/7.0/cli/conf.d/ && \
  cp -f /home/docker/php/default_opcache_blacklist /etc/php/7.0/opcache_blacklist && \
  sed -i 's/^listen = .*/listen = 80/g' /etc/php/7.0/fpm/pool.d/www.conf && \
  sed -i 's/^pm = .*/pm = ondemand/g' /etc/php/7.0/fpm/pool.d/www.conf && \
  sed -i 's/;daemonize = .*/daemonize = no/g' /etc/php/7.0/fpm/php-fpm.conf && \
  sed -i 's/^pm\.max_children = .*/pm.max_children = 8/g' /etc/php/7.0/fpm/pool.d/www.conf && \
  sed -i 's/^;pm\.process_idle_timeout = .*/pm.process_idle_timeout = 15s/g' /etc/php/7.0/fpm/pool.d/www.conf && \
  sed -i 's/^;pm\.max_requests = .*/pm.max_requests = 50/g' /etc/php/7.0/fpm/pool.d/www.conf && \
  sed -i 's/^;request_terminate_timeout = .*/request_terminate_timeout = 7200/g' /etc/php/7.0/fpm/pool.d/www.conf

RUN apt-get install -y supervisor procps

# syslog
RUN echo "local0.* /var/www/html/log/drupal.log" >> /etc/rsyslog.conf && \
  sed -i 's/\*\.\*;auth,authpriv\.none.*/*.*;local0.none;auth,authpriv.none -\/var\/log\/syslog/g' /etc/rsyslog.conf

# wkhtmltopdf
RUN \
  apt-get install -y fonts-droid fontconfig libfontconfig1 libfreetype6 libpng12-0 libssl1.0.0 libx11-6 libxext6 libxrender1 xfonts-75dpi xfonts-base && \
  cd /tmp && \
  wget -nv https://bitbucket.org/wkhtmltopdf/wkhtmltopdf/downloads/wkhtmltox-0.13.0-alpha-7b36694_linux-jessie-amd64.deb -O wkhtmltox.deb && \
  dpkg -i wkhtmltox.deb && \
  rm -f wkhtmltox.deb && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

ADD container/supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD container/mysql/mysql-init.sh /usr/local/bin/mysql-init.sh

### END
WORKDIR /var/www/html
ENV TERM=xterm
CMD ["/usr/bin/supervisord"]
