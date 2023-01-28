#!/bin/bash

# Parse arguments passed to the script and set them as global variables
parseArgs() {
  for nv in $@ ; do
    [ -z "$(grep '=' <<< $nv)" ] && continue;
    name="$(echo $nv | cut -d'=' -f1)"
    value="$(echo $nv | cut -d'=' -f2-)"
    eval "${name^^}=$value" 2> /dev/null || true
  done
}

parseArgs $@

source ./credentials.sh

build() {
  docker build -t bu-wp-assets-object-lambda:latest .
  docker rmi $(docker images --filter dangling=true -q) 2> /dev/null || true
}

run() {

  [ -n "$PROFILE" ] && setLocalCredentials $PROFILE

  [ ! -d logs ] && mkdir logs

  export MSYS_NO_PATHCONV=1

  getAcctNbr() {
    if [ -n "$AWS_ACCOUNT_NBR" ] ; then
      echo "$AWS_ACCOUNT_NBR"
    else
      source $(pwd)/vars.env 2>&1 > /dev/null
      aws sts get-caller-identity | jq -r '.Account' 2> /dev/null
    fi
  }
  getRegion() {
    [ -n "$REGION" ] && echo "$REGION" || echo "us-east-1"
  }

  # STRANGE AND FRUSTRATING BUG: Cannot feed the environment variables separately into the container using -e.
  # They show up on the container when you run docker inspect, but when you shell into the container 
  # and run the env command, the only one that shows up is AWS_SESSION_TOKEN, WTF!!!
  # WORKAROUND: Putting the environment variables into a file and using --env-file.
  # (Note: This is probably a windows/docker desktop/WSL bug - won't occur on linux and I doubt it would on a mac)
  echo "#/bin/bash" > vars.env
  echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> vars.env
  echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> vars.env
  echo "AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN" >> vars.env
  echo "AWS_ACCOUNT_NBR=$(getAcctNbr)" >> vars.env
  echo "REGION=$(getRegion)" >> vars.env
  echo "OLAP=$OLAP" >> vars.env

  docker run \
    -d \
    --name ol \
    -p 80:80 \
    -p 443:443 \
    --env-file vars.env \
    -v $(pwd)/hello.html:/var/www/warren/hello.html \
    -v $(pwd)/default.conf:/etc/apache2/sites-enabled/default.conf \
    -v $(pwd)/logs:/var/log/apache2 \
    bu-wp-assets-object-lambda:latest

  # docker run \
  #   -d \
  #   --name ol \
  #   -p 80:80 \
  #   -p 443:443 \
  #   -v $(pwd)/hello.html:/var/www/warren/hello.html \
  #   -v $(pwd)/default.conf:/etc/apache2/sites-enabled/default.conf \
  #   -v $(pwd)/logs:/var/log/apache2 \
  #   -e OLAP:$OLAP \
  #   -e AWS_ACCOUNT_NBR:$AWS_ACCOUNT_NBR \
  #   -e REGION=$REGION \
  #   -e AWS_ACCESS_KEY_ID:$AWS_ACCESS_KEY_ID \
  #   -e AWS_SECRET_ACCESS_KEY:$AWS_SECRET_ACCESS_KEY \
  #   -e AWS_SESSION_TOKEN:$AWS_SESSION_TOKEN \
  #   bu-wp-assets-object-lambda:latest
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

# sh docker.sh task=deploy profile=infnprd olap=resize-olap

# sh docker.sh task=run olap=resize-olap aws_access_key_id=[ID] aws_secret_access_key=[KEY] aws_account_nbr=770203350335