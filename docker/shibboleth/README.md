# Containerized apache server for S3 assets as shibboleth SP

This folder comprises a docker build context for an image that defines an apache server.
When a container is run, the apache server performs that task of retrieving s3 artifacts from a predefined bucket via an object lambda endpoint.
Initially apache will require that the user be authenticated with the shib-test.bu.edu and will perform the role of service provider to the IDP.

### Steps:

1. **Create stack:**
   Make sure the main cloudformation stack has been created so that the bucket and endpoint are available. *(See: [README.md](../../Readme.md))*
   For now, DO NOT opt to create a public ec2 instance as part of stack creation. That ec2 would be reachable over the generated elastic ip address, but we would need it to be reachable over the address that the shibboleth IDP has been configured to redirect successful authentication requests to.
   Apache will be operating from a container we run locally and contact through that special hostname already known to the IDP *(see next step)*.

2. **Host file:**
   Make an entry in your host file. This should match the host portion of the "SERVER_NAME" value in use further below.
   In this case we are borrowing (and impersonating) an existing IDP configuration for kuali.
   
   - *(NOTE: Once a ticket is put in to have the desired shibboleth configuration installed at the IDP, the value reflecting a portion of the entity_id can be used instead. Also, the ec2 option for stack creation can be revisited at this point if route53 is involved and BU networking can delegate name resolution to it - SEE: INC13537073)*
   
   ```
   127.0.0.1	warren.kualitest.research.bu.edu
   ```
   
3. **Prepare a parameters file:**
   Create a file with name/value pairs that need to be in the running containers environment as variables *(the docker "--env-file" switch is used).*

   - OLAP: The name of the object lambda endpoint created as part of step 1

   - SERVER_NAME: The entity our apache virtual host will "impersonate" and has been placed earlier in the hosts file.

   - SP_ENTITY_ID: The service provider ID that has been registered with the IDP *(in samlMeta.xml as "entityID" attribute)*
      You will probably see the following reply from the IDP if you do not set this to the exact value the IDP expects:

      ```
      Web Login Service - Unsupported Request
      The application you have accessed is not registered for use with this service.
      ```

   - SP_HOME_URL: The 

   - IDP_ENTITY_ID: The entity ID of the shib-test IDP

   - SHIB_SP_KEY: The name of the private key used by the shibboleth2.xml file. The "private" part of the keypair whose public value is known by the IDP. The file itself will be mounted into the /etc/shibboleth directory of the container with this name.

   - SHIB_CERT_KEY: The name of the public key used by the shibboleth2.xml file. The "public" part of the keypair known by the IDP. The file itself will be mounted into the /etc/shibboleth directory of the container with this name

   - SHELL: Set this to true, and the container will stay running, but apache won't be started. Usefull for shelling into the container and examining how the startup-script referenced by the Dockerfile CMD instruction went.

   EXAMPLE:
   
   ```
   OLAP=bu-wp-assets-object-lambda-dev-olap
   SERVER_NAME=warren.kualitest.research.bu.edu
   SP_ENTITY_ID=https://*.kualitest.research.bu.edu/shibboleth
   IDP_ENTITY_ID=https://shib-test.bu.edu/idp/shibboleth
   SHIB_SP_KEY=sp-key.pem
   SHIB_SP_CERT=sp-cert.pem
   SHELL=true
   ```
   
4. **Prepare the keypair**
   Make sure the private key and public cert are available in the current directory for mounting to the container.
   NOTE:

   - SHIB_SP_KEY should reflect the name of the private key file.
   - SHIB_SP_CERT should reflect the names of public cert file.
   - Both are referenced in the `"<CredentialResolver>"` element of shibboleth2.xml.
   - The public cert file content was the same used for the `"<ds:X509Certificate>"` element value in the samlMeta.xml file
      provided for the IDP when it was originally set up.

5. **Run container:**
   Build the container:

   ```
   cd docker/shibboleth
   sh docker.sh task=build
   ```

   then run the container:

   ```
   cd docker/shibboleth
   sh docker.sh task=run profile=infnprd
   ```

   In the prior example, the named profile in the ~/.aws/credentials is referenced. From it the credentials and account number are derived.
   However, you can also enter those individually:

   ```
   cd docker/shibboleth
   sh docker.sh \
     task=run \
     aws_access_key_id=[ID] \
     aws_secret_access_key=[KEY] \
     aws_account_nbr=770203350335
   ```

   You can also build/rebuild and run/rerun the container in a single step *(use "deploy" instead of "run")*:

   ```
   cd docker/shibboleth
   sh docker.sh task=deploy profile=infnprd
   ```

6. **Browser:**
   Apache is running with a virtual host that matches the host file entry made earlier.
   This means you can get to it through the container on port 80 or 443: 
   https://warren.kualitest.research.bu.edu/index.htm
   or you can target an image directly:
   https://warren.kualitest.research.bu.edu/dilbert1.gif

NOTES:

https://medium.com/@winma.15/shibboleth-sp-installation-in-ubuntu-d284b8d850da