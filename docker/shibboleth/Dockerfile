FROM bu-wp-assets-object-lambda

# Install mod_shib
RUN \
  apt-get -y install libapache2-mod-shib2 vim curl && \
  a2enmod auth_basic && \
  apache2ctl -M | grep mod_shib && \
  a2enmod shib 

COPY apache-startup.sh /etc/apache2/
COPY shibboleth2-template.xml /etc/shibboleth/

RUN \
  chmod a+x /etc/apache2/*.sh && \
  chmod a+rw /etc/shibboleth/shibboleth2-template.xml

CMD ["/etc/apache2/apache-startup.sh"]