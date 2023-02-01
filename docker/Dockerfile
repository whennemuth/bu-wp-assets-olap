FROM ubuntu:20.04

ENV CONTAINER_TIMEZONE="UTC"
# ENV CONTAINER_TIMEZONE="America/New_York"

RUN ln -snf /usr/share/zoneinfo/$CONTAINER_TIMEZONE /etc/localtime && echo $CONTAINER_TIMEZONE > /etc/timezone

# Install dependencies
RUN apt update && \
  apt install -y apache2 && \
  apt install -y dos2unix

# Install apache and write hellow world message
# RUN echo "Hello World!" > /var/www/index.html

# Configure apache
RUN a2enmod rewrite ssl headers proxy proxy_http rewrite env
RUN chown -R www-data:www-data /var/www
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_RUN_DIR /var/www/html

COPY signer.sh /etc/apache2/
COPY credentials.sh /etc/apache2/
COPY listener.sh /etc/apache2/
COPY favicon.ico /etc/apache2/
RUN dos2unix /etc/apache2/*.sh && \
  chmod a+x /etc/apache2/*.sh && \
  chmod a+r /etc/apache2/*ico && \
  echo "AddType image/x-icon .ico" >> /etc/apache2/apache2.Configure
EXPOSE 80
EXPOSE 443

# CMD [ "/usr/sbin/apache2", "-D",  "FOREGROUND" ]
CMD [ "/usr/sbin/apache2", "-X", "-D",  "FOREGROUND", "-e", "debug" ]