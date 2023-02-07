#!/bin/bash

noCredentials() {
  local creds='ok'
  [ -z "$AWS_ACCESS_KEY_ID" ] && creds=''
  [ -z "$AWS_SECRET_ACCESS_KEY" ] && creds=''
  [ -z "$creds" ] && true || false
}

# If called, this function assumes the existence of a .aws/credentials file in the home directory.
# If found, this file will be searched for the specified profile, and the individual credentials that
# make up that profile will be exported as individual variables to the environment.
# Will be used if you are calling this script directly, outside of a containerized or server 
# environment and want to use your own local aws profile.
setLocalCredentials() {
  local profile="$1"
  [ ! -f ~/.aws/credentials ] && return 0
  local foundHeader='false'
  isHeader() {
    local line="$1"
    [ -n "$(echo "$line" | grep -iP '\[[^\]]+\]')" ] && true || false
  }
  isSoughtHeader() {
    local line="$1"
    [ -n "$(echo "$line" | grep -i '\['$profile'\]')" ] && true || false
  }
  _export() {
    read variable
    echo "export $variable"
  }
  trim() {
    read trimmable
    echo "$trimmable" | sed 's/ = /=/'
  }
  uppercase() {
    read nv
    local name="$(echo $nv | cut -d'=' -f1)"
    local value="$(echo $nv | cut -d'=' -f2-)"
    printf "${name^^}=$value"
  }
  emptyOrAllWhitespace() {
    local line="$1"
    ([ -z "$line" ] || [ -z "$(echo "$line" | grep -E '\S+')" ]) && true || false
  }

  while read -r line; do 
    if isSoughtHeader "$line" ; then
      foundHeader='true'
    elif [ "$foundHeader" == 'true' ] ; then
      if isHeader "$line" ; then
        return 0
      fi
      if ! emptyOrAllWhitespace "$line" ; then
        local cmd="$(echo "$line" | trim | uppercase | _export)"
        echo "$cmd"
        eval "$cmd"
      fi
    fi
  done < ~/.aws/credentials

  # In case the credentials file stored the variable names in lowercase, set uppercase counterparts.
  [ -z "$AWS_ACCESS_KEY_ID" ] && AWS_ACCESS_KEY_ID=$aws_access_key_id
  [ -z "$AWS_SECRET_ACCESS_KEY" ] && AWS_SECRET_ACCESS_KEY=$aws_secret_access_key
  [ -z "$AWS_SESSION_TOKEN" ] && AWS_SESSION_TOKEN=$aws_session_token
}

anyCredentials() {
  local profile="$1"
  local found='true'
  if noCredentials ; then
    if [ -z "$profile" ] ; then
      found='false'
    else
      setLocalCredentials $profile
      if noCredentials ; then
        found='false'
      fi
    fi
  fi
  [ $found == 'true' ] && 'true' || 'false'
}