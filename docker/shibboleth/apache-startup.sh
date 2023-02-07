#!/bin/bash


# Paves over the shibboleth.xml file with a copy of the shibboleth2-template.xml file with the placeholder
# values replaced with the real values that should be available now as environment variables.
editShibbolethXML() {

  echo "editShibbolethXML..."
  local sp_key=${SHIB_SP_KEY:-"sp-key.pem"}
  local sp_cert=${SHIB_SP_CERT:-"sp-cert.pem"}

  insertSpEntityId() { sed "s|SP_ENTITY_ID|$SP_ENTITY_ID|g" < /dev/stdin; }

  insertIdpEntityId() { sed "s|IDP_ENTITY_ID|$IDP_ENTITY_ID|g" < /dev/stdin; }

  insertSpKey() { sed "s|SHIB_SP_KEY|$sp_key|g" < /dev/stdin; }

  insertSpCert() { sed "s|SHIB_SP_CERT|$sp_cert|g" < /dev/stdin; }

  cat /etc/shibboleth/shibboleth2-template.xml \
    | insertSpEntityId \
    | insertIdpEntityId \
    | insertSpKey \
    | insertSpCert \
  > /etc/shibboleth/shibboleth2.xml
}

# Generate a shibboleth idp metadata file if one does not already exist.
getIdpMetadataFile() {
  echo "getIdpMetadataFile..."
  local xmlfile=/etc/shibboleth/idp-metadata.xml
  if [ ! -f $xmlfile ] ; then
    curl https://shib-test.bu.edu/idp/shibboleth -o $xmlfile
  fi
}

# Add buPrincipleNameID (BUID) as an attribute to extract from SAML assertions returned back from the IDP. 
modifyAttributesFile() {
  echo "modifyAttributesFile..."
  local find="<\/Attributes>"
  local insertBefore="    <Attribute name=\"urn:oid:1.3.6.1.4.1.9902.2.1.9\" id=\"buPrincipalNameID\"/>"
  local xmlfile="/etc/shibboleth/attribute-map.xml"
  sed -i "/${find}/i\ ${insertBefore}" ${xmlfile}
}

# Duplicate the default.conf with as a new virtual host (different ServerName directive) with added shibboleth configurations. 
createShibVirtualHost() {
  echo "createShibVirtualHost..."

  # Replace the ServerName and related place-holders with the actual ServerName value
  setServerName() { sed "s|local-ol|${SERVER_NAME:-"local-ol"}|g" < /dev/stdin; }

  # Uncomment the include directive for the shibboleth apache conf content
  includeShibConf() { sed "s|# IncludeOptional|IncludeOptional|g" < /dev/stdin; }

  cat /etc/apache2/sites-available/default.conf \
    | setServerName \
    | includeShibConf \
  > /etc/apache2/sites-enabled/shibboleth.conf
}

startShibD() {
  service shibd start
}

# Start the apache server.
startApache() {
  echo "startApache..."
  if [ "$DEBUG" == 'true' ] ; then
    /usr/sbin/apache2 -X -D FOREGROUND -e debug
  else
    /usr/sbin/apache2 -D FOREGROUND
  fi
}

if [ "$SHELL" == 'true' ] ; then
  # Keeps the container running, but apache is not started.
  tail -f /dev/null
else
  editShibbolethXML

  getIdpMetadataFile

  modifyAttributesFile

  createShibVirtualHost

  startShibD

  startApache
fi