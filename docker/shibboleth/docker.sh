#!/bin/bash

# See README.md file for usage.

source ../utils.sh

source ../baseline/credentials.sh

parseArgs $@

build() {
  docker build -t bu-wp-assets-object-lambda-shib:latest .
  docker rmi $(docker images --filter dangling=true -q) 2> /dev/null || true
}

run() {

  # Based on the profile specified, set the individual aws credentials as environment variables.
  [ -n "$PROFILE" ] && setLocalCredentials $PROFILE

  # Create a directory for the container to mount to for log output.
  [ ! -d logs ] && mkdir logs || rm -rf logs/*
  [ ! -d logs-shib ] && mkdir logs-shib || rm -rf logs-shib/*

  missingEnvVar() {
    (
      source ./vars.env
      if [ -z "$OLAP" ] ; then echo "OLAP"; return; fi 
      if [ -z "$SERVER_NAME" ] ; then echo "SERVER_NAME"; return; fi
      if [ -z "$IDP_ENTITY_ID" ] ; then echo "IDP_ENTITY_ID"; return; fi
      if [ -z "$SHIB_SP_KEY" ] ; then echo "SHIB_SP_KEY"; return; fi
      if [ -z "$SHIB_SP_CERT" ] ; then echo "SHIB_SP_CERT"; return; fi
      if [ -z "$AWS_ACCESS_KEY_ID" ] ; then echo "AWS_ACCESS_KEY_ID"; return; fi
      if [ -z "$AWS_SECRET_ACCESS_KEY" ] ; then echo "AWS_SECRET_ACCESS_KEY"; return; fi
      if [ -z "$AWS_SESSION_TOKEN" ] ; then echo "AWS_SESSION_TOKEN"; return; fi
      if [ -z "$AWS_ACCOUNT_NBR" ] ; then echo "AWS_ACCOUNT_NBR"; return; fi
      if [ -z "$REGION" ] ; then echo "REGION"; return; fi
      if [ -z "$SP_ENTITY_ID" ] ; then echo "SP_ENTITY_ID"; return; fi
    )
  }

  # Get the name of the public or private key set in the env-file
  getKeyName() {
    case "$1" in
      public)
        ( source ./vars.env && echo "$SHIB_SP_KEY" ) ;;
      private)
        ( source ./vars.env && echo "$SHIB_SP_CERT" ) ;;
    esac
  }

  # Create the environment variables file for the docker container.
  createEnvFile
  
  local missing="$(missingEnvVar)"

  if [ -n "$missing" ] ; then
    echo "Missing environment variable: $missing"
  else
    echo "Running container:"
    docker run \
      -d \
      --name ol \
      -p 80:80 \
      -p 443:443 \
      --env-file vars.env \
      -v $(dirname $(pwd))/baseline/default.conf:/etc/apache2/sites-available/default.conf \
      -v $(pwd)/apache-shibboleth.conf:/etc/apache2/sites-available/apache-shibboleth.conf \
      -v $(pwd)/$(getKeyName 'private'):/etc/shibboleth/$(getKeyName 'private') \
      -v $(pwd)/$(getKeyName 'public'):/etc/shibboleth/$(getKeyName 'public') \
      -v $(pwd)/logs:/var/log/apache2 \
      -v $(pwd)/logs-shib:/var/log/shibboleth \
      bu-wp-assets-object-lambda-shib:latest
  fi
}

kill() {
  docker rm -f ol 2> /dev/null || true
}

case "$TASK" in
  run)
    kill && run
    ;;
  build)
    kill && build
    ;;
  deploy)
    kill && build && run
    ;;
esac

