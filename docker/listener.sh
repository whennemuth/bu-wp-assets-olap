#!/bin/bash

while read object_key_with_timestamp ; do
  objectKey="$(echo $object_key_with_timestamp | cut -d'|' -f1)"
  timestamp="$(echo $object_key_with_timestamp | cut -d'|' -f2)"
  # Apache sends a "TIME" variable as UTC in the format YYYYMMDDSSSSSS.
  # Convert it to UTC time in ISO 8601 basic format ("Need "T" and "Z").
  timestamp="${timestamp:0:8}T${timestamp:8}Z"
  retval="$(sh /etc/apache2/signer.sh "task=auth" "object_key=$objectKey" "time_stamp=$timestamp" 2>&1 | tee /tmp/output.log)"
  if [ -$? -eq 0 ] ; then
    if [ "$retval" == 'NULL' ] || [ -z "$retval" ]; then
      echo -ne 'NULL'
    else
      echo "$retval"
    fi
  else
    echo -ne 'NULL'
  fi
done