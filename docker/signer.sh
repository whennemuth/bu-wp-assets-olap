#!/bin/bash

# This script creates a signed AWS API s3 getObject request.
# Related AWS documentation:
#   - https://docs.aws.amazon.com/general/latest/gr/create-signed-request.html#create-canonical-request
#   - https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
#   - https://czak.pl/2015/09/15/s3-rest-api-with-curl.html

# EXAMPLES:

  # ----------------------------------------------------------------
  #    Get creds from profile and pass an explicit timestamp
  # ----------------------------------------------------------------
  # sh signer.sh \
  #   profile=infnprd \
  #   task=curl \
  #   object_key=2.jpg \
  #   time_stamp=$(date --utc +'%Y%m%dT%H%M000000Z')
  # 
  # ----------------------------------------------------------------
  #    Export the credentials and invoke default of current timestamp
  # ----------------------------------------------------------------
  # set -a
  # aws_access_key_id=[id]
  # aws_secret_access_key=[key]
  # aws_session_token=[token]
  # sh signer.sh \
  #   task=curl \
  #   object_key=2.jpg
# set -x
[ -f ./credentials.sh ] && source ./credentials.sh
[ -f /etc/apache2/credentials.sh ] && source /etc/apache2/credentials.sh

# Parse arguments passed to the script and set them as global variables
parseArgs() {
  for nv in $@ ; do
    [ -z "$(grep '=' <<< $nv)" ] && continue;
    name="$(echo $nv | cut -d'=' -f1)"
    value="$(echo $nv | cut -d'=' -f2-)"
    eval "${name^^}=$value" 2> /dev/null || true
  done
}

setGlobals() {  
  [ -z "$TIME_STAMP" ] && TIME_STAMP="$(date --utc +'%Y%m%dT%H%M%SZ')"
  DATE_STAMP="${TIME_STAMP:0:8}"
  SERVICE="s3"
  HASH_ALG='AWS4-HMAC-SHA256'
  REQUEST_TYPE='aws4_request'
  SIGNED_HEADERS="host;x-amz-content-sha256;x-amz-date"
  EMPTY_STRING="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  [ -n "$AWS_SESSION_TOKEN" ] && SIGNED_HEADERS="$SIGNED_HEADERS;x-amz-security-token"
  [ -z "$REGION" ] && REGION="us-east-1"
  [ -z "$HOST" ] && HOST="resize-ap-up5a46gsosfky1aymqrgpz9otef9yuse1a-s3alias.${SERVICE}.${REGION}.amazonaws.com"
  [ -z "$OBJECT_KEY" ] && OBJECT_KEY="2.jpg"
  # Trim off any leading "/"
  [ "${OBJECT_KEY:0:1}" == '/' ] && OBJECT_KEY=${OBJECT_KEY:1}
}

hmac_sha256() {
  key="$1"
  data="$2"
  echo -ne "$data" | openssl dgst -sha256 -mac HMAC -macopt "$key" | sed 's/^.* //' | tr -d '\n'
}

getCanonicalRequest() {
  local httpmethod="GET"
  local canonicalURI="/${OBJECT_KEY}"
  local canonicalQueryString=""
  local canonicalHeader1="host:$HOST"
  local canonicalHeader2="x-amz-content-sha256:$EMPTY_STRING"
  local canonicalHeader3="x-amz-date:${TIME_STAMP}"
  local canonicalHeaders="${canonicalHeader1}\n${canonicalHeader2}\n${canonicalHeader3}\n"
  if [ -n "$AWS_SESSION_TOKEN" ] ; then
    canonicalHeaders="${canonicalHeaders}x-amz-security-token:$AWS_SESSION_TOKEN\n"
  fi
  local hashedPayload=$EMPTY_STRING
  echo -ne "${httpmethod}\n${canonicalURI}\n${canonicalQueryString}\n${canonicalHeaders}\n${SIGNED_HEADERS}\n${hashedPayload}"
}

getStringToSign() {
  sha256() {
    echo -ne "$1" | openssl dgst -sha256 -hex | sed 's/^.* //'
  }
  local scope="${DATE_STAMP}/${REGION}/${SERVICE}/${REQUEST_TYPE}"
  local canonicalRequest="$(getCanonicalRequest)"
  local canonicalRequestHash="$(sha256 "$canonicalRequest")"
  echo -ne "${HASH_ALG}\n${TIME_STAMP}\n${scope}\n${canonicalRequestHash}"
}

getSigningKey() {
  local dateKey=$(hmac_sha256 key:"AWS4$AWS_SECRET_ACCESS_KEY" $DATE_STAMP)
  local dateRegionKey=$(hmac_sha256 "hexkey:$dateKey" $REGION)
  local dateRegionServiceKey=$(hmac_sha256 "hexkey:$dateRegionKey" $SERVICE)
  local signingKey=$(hmac_sha256 "hexkey:$dateRegionServiceKey" "aws4_request")
  echo -ne "$signingKey"
}

getSignature() {
  echo -ne $(hmac_sha256 "hexkey:$(getSigningKey)" "$(getStringToSign)")
}

getAuthHeader() {
  echo -ne \
    "$HASH_ALG \
    Credential=${AWS_ACCESS_KEY_ID}/${DATE_STAMP}/${REGION}/${SERVICE}/${REQUEST_TYPE}, \
    SignedHeaders=$SIGNED_HEADERS, \
    Signature=$(getSignature)" | sed 's/ //g' | sed 's/Credential=/ Credential=/'
}

# Test the generated signature by using it to download an s3 object with curl.
doCurl() {
  local filename="$(echo "$OBJECT_KEY" | awk -F/ '{print $NF}')"

  if [ -n "$AWS_SESSION_TOKEN" ] ; then
    curl \
      -o "$filename" \
      -v https://${HOST}/${OBJECT_KEY} \
      -H "Authorization: $(getAuthHeader)" \
      -H "X-Amz-Content-SHA256: $EMPTY_STRING" \
      -H "X-Amz-Date: $TIME_STAMP" \
      -H "X-Amz-Security-Token: $AWS_SESSION_TOKEN"
  else
    curl \
      -o "$filename" \
      -v https://${HOST}/${OBJECT_KEY} \
      -H "Authorization: $(getAuthHeader)" \
      -H "X-Amz-Content-SHA256: $EMPTY_STRING" \
      -H "X-Amz-Date: $TIME_STAMP"
  fi
}

run() {
  parseArgs $@

  if anyCredentials "$PROFILE" ; then

    setGlobals $@
    
    case "$TASK" in
      auth)
        # For proper return of value see: https://httpd.apache.org/docs/2.4/rewrite/rewritemap.html#prg
        auth="$(getAuthHeader)"
        statcode=$?
        [ "$INCLUDE_TIMESTAMP" == 'true' ] && auth="${TIME_STAMP}|${auth}"
        if [ $statcode -eq 0 ] || [ -z "$auth" ] ; then
          # Returned value must be terminated by a newline character.
          echo "$auth"
        else
          # "If there is no corresponding lookup value, the map program should return the four-character string "NULL" to indicate this."
          echo "ERROR IN signer.sh" >> /tmp/output.log
          echo -ne "NULL"
        fi
        ;;
      curl)
        doCurl
        ;;
    esac
  else
    echo "NO CREDENTIALS" >> /tmp/output.log
    echo -ne "NULL"
  fi
}

# If the listener is sourcing the script, do nothing (yet), else run the indicated task.
[ "$1" != 'wait' ] && run $@
