#!/bin/bash

# Parse arguments passed to the script and set them as global variables
parseArgs() {

  for nv in $@ ; do
    [ -z "$(grep '=' <<< $nv)" ] && continue;
    name="$(echo $nv | cut -d'=' -f1)"
    value="$(echo $nv | cut -d'=' -f2-)"
    eval "${name^^}=$value" 2> /dev/null || true
    if [ "${name^^}" == 'PROFILE' ] ; then
      export AWS_PROFILE="$value"
    fi
  done
}

dryrun() {
  [ "${DRYRUN,,}" == 'true' ] && true || false
}

run() {
  getStackParms() {
    local switch='--parameter-overrides'
    if [ -n "$EC2" ] ; then
      [ -z "$parms" ] && parms=$switch
      parms="${parms} ${override} CreateEC2=${EC2}"
    fi
    if [ -n "$BUCKET_USER" ] ; then
      [ -z "$parms" ] && parms=$switch
      parms="${parms} ${override} CreateBucketUser=${BUCKET_USER}"
    fi
    if [ -n "$HOST_NAME" ] ; then
      [ -z "$parms" ] && parms=$switch
      parms="${parms}${override} HostName=${HOST_NAME}"
    fi
    if [ -n "$SHIB" ] ; then
      [ -z "$parms" ] && parms=$switch
      parms="${parms}${override} Shibboleth=${SHIB}"
    fi
    echo "$parms"
  }
  runCommand() {
    echo "$1"
    if dryrun ; then return 0; fi
    eval "$1"
  }
  build() {
    runCommand "sam build"
  }
  package() {
    runCommand "sam package --force-upload"
  }
  deploy() {
    runCommand "sam deploy --debug --force-upload $(getStackParms) && loadAssetBucket"
    # runCommand "sam deploy --debug $(getStackParms) && loadAssetBucket"
  }
  delete() {
    runCommand "emptyAssetBucket && sam delete --no-prompts"
  }
  sync() {
    runCommand "sam sync --code --resource-id LambdaFunction --no-dependency-layer"
    # runCommand "sam sync --code --resource-id LambdaFunction --dependency-layer"
  }
  logs() {
    runCommand "sam logs --stack-name $(getStackName)"
  }

  parseArgs $@

  case "${TASK:-'sync'}" in
    build)
      build ;;
    package)
      package ;;
    deploy)
      build && deploy ;;
    redeploy)
      delete && build && deploy ;;
    sync)
      sync ;;
    logs)
      logs ;;
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
  local landscape=${1:-"default"}
  local header=$landscape'\.global\.parameters'
  grep -E '('$header')|(stack_name)' samconfig.toml \
    | grep -E -A1 $header \
    | tail -1 \
    | grep -oE '"([^"]+)"' \
    | sed 's/\"//g'
}

getAssetBucketName() {
  echo "$(getStackName)-assets"
}

run $@