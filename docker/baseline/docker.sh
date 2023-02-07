#!/bin/bash

source ../utils.sh

source ./credentials.sh

parseArgs $@

build() {
  docker build -t bu-wp-assets-object-lambda:latest .
  docker rmi $(docker images --filter dangling=true -q) 2> /dev/null || true
}

run() {

  [ -n "$PROFILE" ] && setLocalCredentials $PROFILE

  [ ! -d logs ] && mkdir logs

  createEnvFile && \
    echo "OLAP=$OLAP" >> vars.env
  
  docker run \
    -d \
    --name ol \
    -p 80:80 \
    -p 443:443 \
    --env-file vars.env \
    -v $(pwd)/default.conf:/etc/apache2/sites-enabled/default.conf \
    -v $(pwd)/logs:/var/log/apache2 \
    bu-wp-assets-object-lambda:latest
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

# sh docker.sh \
#   task=deploy \
#   profile=infnprd \
#   olap=bu-wp-assets-object-lambda-dev-olap

# sh docker.sh \
#   task=deploy \
#   olap=bu-wp-assets-object-lambda-dev-olap \
#   aws_access_key_id=[ID] \
#   aws_secret_access_key=[KEY] \
#   aws_account_nbr=770203350335