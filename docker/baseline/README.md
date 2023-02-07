# Containerized apache server for S3 assets

This folder comprises a docker build context for an image that defines an apache server.
When a container is run, the apache server performs that task of retrieving s3 artifacts from a predefined bucket via an object lambda endpoint.

### Steps:

1. **Create stack:**
   Make sure the main cloudformation stack has been created so that the bucket and endpoint are available. *(See: [README.md](../../Readme.md))*

   - *NOTE: If you opted to also create a public ec2 instance as part of stack creation, all the following steps are automatically executed on that server and you can later reach it via the elastic IP address of the ec2 instance if you want to, ie: https://312.28.15.1/index.htm.*

2. **Host file:**
   Make an entry in your host file: 

   ```
   127.0.0.1	local-ol
   ```

3. **Run container:**
   Build the container:

   ```
   cd docker/baseline
   sh docker.sh task=build
   ```

   then run the container *(the "olap" parameter is the name of the object lambda endpoint created in step one):*

   ```
   cd docker/baseline
   sh docker.sh \
     task=run \
     profile=infnprd \
     olap=bu-wp-assets-object-lambda-dev-olap
   ```

   In the prior example, the named profile in the ~/.aws/credentials is referenced. From it the credentials and account number are derived.
   However, you can also enter those individually:

   ```
   cd docker/baseline
   sh docker.sh \
     task=run \
     olap=bu-wp-assets-object-lambda-dev-olap \
     aws_access_key_id=[ID] \
     aws_secret_access_key=[KEY] \
     aws_account_nbr=770203350335
   ```

   You can also build/rebuild and run/rerun the container in a single step *(use "deploy" instead of "run")*:

   ```
   cd docker/baseline
   sh docker.sh \
     task=deploy \
     profile=infnprd \
     olap=bu-wp-assets-object-lambda-dev-olap
   ```

4. **Browser:**
   Apache is running with a virtual host that matches the host file entry made earlier.
   This means you can get to it through the container on port 80 or 443: 
   https://local-ol/index.htm
   or you can target an image directly:
   https://local-ol/dilbert1.gif