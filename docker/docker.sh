#!/bin/bash

source ./credentials.sh

build() {
  docker build -t bu-wp-assets-object-lambda:latest .
}

run() {

  setLocalCredentials $profile

  export MSYS_NO_PATHCONV=1
  docker run \
    -d \
    --name ol \
    -p 80:80 \
    -p 443:443 \
    -v $(pwd)/hello.html:/var/www/warren/hello.html \
    -v $(pwd)/default.conf:/etc/apache2/sites-enabled/default.conf \
    -e HOST:"resize-ap-up5a46gsosfky1aymqrgpz9otef9yuse1a-s3alias.s3.us-east-1.amazonaws.com" \
    -e AWS_ACCESS_KEY_ID:"$AWS_ACCESS_KEY_ID" \
    -e AWS_SECRET_ACCESS_KEY:"$AWS_SECRET_ACCESS_KEY" \
    -e AWS_SESSION_TOKEN:"$AWS_SESSION_TOKEN" \
    bu-wp-assets-object-lambda:latest 
}

kill() {
  docker rm -f ol 2> /dev/null || true
}


task="${1,,}"
shift
profile=${2:-"infnprd"}

case "$task" in
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
