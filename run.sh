#!/bin/bash

TASK=${1:-"sync"}
LANDSCAPE=${2:-"dev"}

run() {
  build() {
    sam build --config-env $LANDSCAPE
  }
  package() {
    sam package --force-upload --config-env $LANDSCAPE
  }
  deploy() {
    sam deploy --force-upload --config-env $LANDSCAPE \
    && \
    loadAssetBucket
  }
  delete() {
    emptyAssetBucket && \
    sam delete --no-prompts --config-env $LANDSCAPE --stack-name $(getStackName)
  }
  case "$TASK" in
    build)
      build ;;
    package)
      package ;;
    deploy)
      build && deploy ;;
    redeploy)
      delete && build && deploy ;;
    sync)
      # sam sync --code --resource-id LambdaFunction --config-env $LANDSCAPE --no-dependency-layer
      sam sync --code --resource-id LambdaFunction --config-env $LANDSCAPE
      ;;
    logs)
      sam logs --stack-name $(getStackName)
      ;;
    delete)
      delete ;;
  esac
}

loadAssetBucket() {
  aws s3 cp assets s3://$(getAssetBucketName) --recursive
}

emptyAssetBucket() {
  aws s3 rm s3://$(getAssetBucketName) --recursive || true
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
  echo "$(getStackName)-assets"
}

run