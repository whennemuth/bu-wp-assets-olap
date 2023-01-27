#!/bin/bash

# source /etc/apache2/env.sh

source /etc/apache2/signer.sh 'wait'

while read parms ; do

  timestamp="$(echo $parms | cut -d'&' -f1)"
  objectkey="$(echo $parms | cut -d'&' -f2)"
  olap="$(echo $parms | cut -d'&' -f3)"
  aws_account_nbr="$(echo $parms | cut -d'&' -f4)"
  region="$(echo $parms | cut -d'&' -f5)"
  aws_access_key_id="$(echo $parms | cut -d'&' -f6)"
  aws_secret_access_key="$(echo $parms | cut -d'&' -f7)"
  aws_session_token="$(echo $parms | cut -d'&' -f8)"
  host="${olap}-${aws_account_nbr}.s3-object-lambda.${region}.amazonaws.com"

  log "timestamp=$timestamp"
  log "objectkey=$objectkey"
  log "host=$host"
  log "aws_access_key_id=$aws_access_key_id"
  log "aws_secret_access_key=$aws_secret_access_key"
  log "aws_session_token=$aws_session_token"
  
  retval="$(run "task=auth" "debug=true" "object_key=$objectkey" "time_stamp=$timestamp" "host=$host" "aws_access_key_id=$aws_access_key_id" "aws_secret_access_key=$aws_secret_access_key" "aws_session_token=$aws_session_token")"
  retcode=$?
  if [ $retcode -eq 0 ] ; then
    if [ "$retval" == 'NULL' ] || [ -z "$retval" ] ; then
      log "retcode=0, NULL"
      echo 'NULL'
    else
      log "retval = \"$retval\""
      echo "$retval"
    fi
  else
    log "retcode=$retcode, NULL"
    echo 'NULL'
  fi
done
