#!/bin/bash

# Parse arguments passed to the script and set them as global variables
parseArgs() {

  uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
  }

  for nv in $@ ; do
    [ -z "$(grep '=' <<< $nv)" ] && continue;
    name="$(echo $nv | cut -d'=' -f1)"
    name="$(uppercase $name)"
    value="$(echo $nv | cut -d'=' -f2-)"
    eval "${name}=$value" 2> /dev/null || true
    if [ "${name}" == 'PROFILE' ] ; then
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
    if [ -n "$OLAP" ] ; then
      [ -z "$parms" ] && parms=$switch
      parms="${parms} ${override} OLAP=${OLAP}"
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
    runCommand "sam package --force-upload --debug"
  }
  deploy() {
    runCommand "sam deploy --debug --force-upload $(getStackParms) --stack-name $(getStackName) && loadAssetBucket"
    # runCommand "sam deploy --debug $(getStackParms) --stack-name $(getStackName) && loadAssetBucket"
  }
  delete() {
    # You must include --region if unguided delete (--no-prompts) and you explicitly include a --stack-name
    # parameter with a value that is not in the samconfig.toml file. See https://github.com/aws/aws-sam-cli/issues/4119
    # This will be that case if a landscape is specified, which leads to a custom stack name using the landscape to be used.
    runCommand "emptyAssetBucket && sam delete --no-prompts --region us-east-1 --stack-name $(getStackName)"
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
    test)
      getStackName ;;
  esac
}

loadAssetBucket() {
  if [ "$OLAP" != 'false' ] ; then
    aws s3 cp assets s3://$(getAssetBucketName) --recursive
  fi
}

emptyAssetBucket() {
  aws s3 rm s3://$(getAssetBucketName) --recursive || true
}

# If the STACK_NAME parameter is not set, the samconfig.toml file is searched for a stack_name value in a 
# section that reflects LANDSCAPE as the config-env. If none is found, the default stack_name is used with the
# LANDSCAPE parameter, if set, appended to the end.
getStackName() {
  if [ -n "$STACK_NAME" ] ; then
    echo "$STACK_NAME"
    return 0
  else
    getStackNameFromConfigFile() {
      local configEnv="$1"
      local header=$configEnv'\.global\.parameters'
      grep -E '('$header')|(stack_name)' samconfig.toml \
        | grep -E -A1 $header \
        | tail -1 \
        | grep -oE '"([^"]+)"' \
        | sed 's/\"//g'
    }

    local stackname="$(getStackNameFromConfigFile $LANDSCAPE)"
    [ -n "$stackname" ] && echo $stackname && return 0

    stackname="$(getStackNameFromConfigFile 'default')"
    [ -n "$LANDSCAPE" ] && echo ${stackname}-$LANDSCAPE
  fi
}

getAssetBucketName() {
  echo "$(getStackName)-assets"
}

run $@