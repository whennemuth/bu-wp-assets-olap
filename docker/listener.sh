#!/bin/bash

# source /etc/apache2/env.sh

source /etc/apache2/signer.sh 'wait'

while read object_key_with_timestamp ; do

  timestamp="$(echo $object_key_with_timestamp | cut -d'&' -f1)"
  objectkey="$(echo $object_key_with_timestamp | cut -d'&' -f2)"
  host="$(echo $object_key_with_timestamp | cut -d'&' -f3)"
  aws_access_key_id="$(echo $object_key_with_timestamp | cut -d'&' -f4)"
  aws_secret_access_key="$(echo $object_key_with_timestamp | cut -d'&' -f5)"
  aws_session_token="$(echo $object_key_with_timestamp | cut -d'&' -f6)"

  echo "timestamp=$timestamp" >> /tmp/output.log
  echo "objectkey=$objectkey" >> /tmp/output.log
  echo "host=$host" >> /tmp/output.log
  echo "aws_access_key_id=$aws_access_key_id" >> /tmp/output.log
  echo "aws_secret_access_key=$aws_secret_access_key" >> /tmp/output.log
  echo "aws_session_token=$aws_session_token" >> /tmp/output.log
  
  retval="$(run "task=auth" "object_key=$objectkey" "time_stamp=$timestamp" "host=$host" "aws_access_key_id=$aws_access_key_id" "aws_secret_access_key=$aws_secret_access_key" "aws_session_token=$aws_session_token")"
  retcode=$?
  if [ $retcode -eq 0 ] ; then
    if [ "$retval" == 'NULL' ] || [ -z "$retval" ] ; then
      echo "retcode=0, NULL" >> /tmp/output.log
      echo 'NULL'
    else
      echo "retval = \"$retval\"" >> /tmp/output.log
      echo "$retval"
    fi
  else
    echo "retcode=$retcode, NULL" >> /tmp/output.log
    echo 'NULL'
  fi
done
