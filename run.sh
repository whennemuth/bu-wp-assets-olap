#!/bin/bash

TASK=${1:-"sync"}
LANDSCAPE=${2:-"dev"}

run() {
  case "$TASK" in
    package)
      sam package --resolve-s3 --force-upload --config-env $LANDSCAPE
      ;;
    deploy)
      sam deploy --resolve-s3 --force-upload --config-env $LANDSCAPE \
      && \
      loadAssetBucket
      ;;
    sync)
      sam sync --code --resource-id LambdaFunction --config-env $LANDSCAPE
      ;;
    logs)
      sam logs --stack-name $(getStackName)
      ;;
    delete)
      emptyAssetBucket && \
      sam delete --config-env $LANDSCAPE
      ;;
  esac
}

loadAssetBucket() {
  aws s3 cp assets s3://$(getAssetBucketName) --recursive
}

emptyAssetBucket() {
  aws s3 rm s3://$(getAssetBucketName) --recursive
}

getStackName() {
  local header='dev\.global\.parameters'
  grep -E '('$header')|(stack_name)' samconfig.toml \
    | grep -E -A1 $header \
    | tail -1 \
    | grep -oE '"([^"]+)"' \
    | sed 's/\"//g'
}

getAssetBucketName() {
  echo "$(getStackName)-images"
}

run