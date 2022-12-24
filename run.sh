#!/bin/bash

TASK=$1
STACK_NAME={2:-"bu-wp-assets-lambda-s3-proxy"}
ASSETS_BUCKET="$STACK_NAME-images"

case "$TASK" in
  package)
    sam package \
      --region us-east-1 \
      --resolve-s3 \
      --force-upload
    ;;
  deploy)
    sam deploy \
      --stack-name $STACK_NAME \
      --region us-east-1 \
      --resolve-s3 \
      --force-upload \
      --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
      --disable-rollback

    [ $? -eq 0 ] && aws s3 cp assets s3://$ASSETS_BUCKET --recursive
    ;;
  delete)
    aws s3 rm s3://bu-wp-assets-lambda-s3-proxy-images --recursive
    sam delete --stack-name $STACK_NAME
    ;;
esac



