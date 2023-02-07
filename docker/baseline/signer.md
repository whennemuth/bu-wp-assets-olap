# Create a signed AWS API request

Usually one would not need to generate their own api requests (with the SigV4 calculations) as the standard aws SDKs and the CLI do this for you.
However, in the case of apache, where requests are being proxied to aws s3 object lambda endpoints, the aws SDKs and CLI are irrelevant since we are confined to http requests. Relevant documentation for signing requests include:

- [Create a canonical request](https://docs.aws.amazon.com/general/latest/gr/create-signed-request.html#create-canonical-request)
- [Sig V4 header-based authentication](https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html)
- [Custom example](https://czak.pl/2015/09/15/s3-rest-api-with-curl.html)

Signer.sh, can either, depending on which you choose, curl the object lambda endpoint, saving the response data to the current directory, or simply output the signature that would have been used by the curl only.

### Steps:

1. **Create stack:**
   Make sure the main cloudformation stack has been created so that the bucket and endpoint are available. *(See: [README.md](../../Readme.md))*

2. **Run the script:**

   - **Signature only** output *(defaulting to the current time)*:

     ```
     sh signer.sh \
         profile=infnprd \
         task=auth \
         aws_account_nbr=770203350335 \
         olap=bu-wp-assets-object-lambda-dev-olap \
         object_key=dilbert1.gif
     ```

     Or providing an explicit time:
     *(You might do this if you ran the cli in debug mode and want to compare the signature it outputs with one this script outputs. If the timestamp, endpoint, and credentials are the same, the signatures should match)*

     ```
     sh signer.sh \
         profile=infnprd \
         task=auth \
         aws_account_nbr=770203350335 \
         olap=bu-wp-assets-object-lambda-dev-olap \
         object_key=dilbert1.gif \
         time_stamp=$(date --utc +'%Y%m%dT%H%M000000Z')
     ```

     In the prior examples, the named profile in the ~/.aws/credentials are referenced. From it the credentials are derived.
     However, you can also enter those individually:

     ```
     sh signer.sh \
         task=auth \
         aws_access_key_id=[id] \
         aws_secret_access_key=[key] \
         aws_session_token=[token] \
         aws_account_nbr=770203350335 \
         olap=olap=bu-wp-assets-object-lambda-dev-olap \
         object_key=dilbert1.gif
     ```

   - **Curl** the resonse data from the object lambda endpoint to the current directory:
     (Simply change the task to "curl" - all other parameter apply as in above examples)

     ```
     sh signer.sh \
         profile=infnprd \
         task=curl \
         aws_account_nbr=770203350335 \
         olap=bu-wp-assets-object-lambda-dev-olap \
         object_key=dilbert1.gif
     ```

     