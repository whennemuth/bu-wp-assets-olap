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
  build() {
    sam build --config-env $LANDSCAPE
  }
  package() {
    sam package --force-upload --config-env $LANDSCAPE
  }
  deploy() {
    local cmd="sam deploy --force-upload --config-env $LANDSCAPE $(getStackParms)"
    echo "$cmd"
    if dryrun ; then return 0; fi
    eval "$cmd" && \
    loadAssetBucket
  }
  delete() {
    emptyAssetBucket && \
    sam delete --no-prompts --config-env $LANDSCAPE --stack-name $(getStackName)
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
      # sam sync --code --resource-id LambdaFunction --config-env $LANDSCAPE --no-dependency-layer
      sam sync --code --resource-id LambdaFunction --config-env $LANDSCAPE --dependency-layer
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

run $@