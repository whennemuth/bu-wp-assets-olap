# Wordpress to cloud object lambda modelling

### Overview:

This is a demo project to prototype an approach for the proxying of s3 content acquisition for http requests, as part of the BU Wordpress to AWS Cloud project

This is done through [Object Lambda](https://docs.aws.amazon.com/AmazonS3/latest/userguide/transforming-objects.html) and [Access Points](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-points.html), using the [Serverless Application Model](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html) *(SAM)*
The AWS reference that is most closely followed is: [Working with GetObject requests in Lambda](https://docs.aws.amazon.com/AmazonS3/latest/userguide/olap-writing-lambda.html). 

### Context:

This approach applies to the overall project as diagrammed below in the section highlighted in red.
This demo does not include the external cloudfront and webrouter - your browser makes requests directly to the ec2 instance.

![diagram1](./assets/public/diagram1.png)



### Prerequisites:

- [Install the SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
- AWS IAM role with admin privileges
- [Visual studio code](https://code.visualstudio.com/download)

### Usage:

Before you run any SAM commands, you will need to prepare the files needed for when [lambda layer](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html) creation is triggered as part of the upcoming stack creation during the SAM deploy/sync executions. These files include the node_modules directory produced by npm in a location where the [`AWS::Serverless::LayerVersion`](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-layerversion.html) expects to find them as per convention.

```
# From the root directory
cp package.json dependencies/nodejs/
cd dependencies/nodejs
npm install -y
```

Now you can run the SAM commands *(validate, package, deploy, delete)* by themselves, or make use of some shortcut script (run.sh) that:

- Includes command parameters dealing with default names and parameters not available for sam toml config files.
- Auto-populates the assets bucket with content upon creation and empties it so it can be deleted along with other resources made during stack creation.

There are multiple options available:

```
# Most basic: Build, package and deploy the app (runs both a sam build and deploy)
source run.sh \
  task=deploy \
  landscape=dev \
  profile=[aws_profile]

# The lambda will assume a default HOST_NAME environment variable of "local-ol", but you can override this:
source run.sh \
  task=deploy \
  landscape=dev \
  host_name=my.custom.hostname \
  profile=[aws_profile]

# If you want the lambda function to include authorization logic (shibboleth header analysis), indicate as follows
source run.sh \
  task=deploy \
  landscape=dev \
  host_name=[my.cn.known.by.the.idp] \
  shib=true \
  profile=[aws_profile]

# If you want also to create a user that has access to the bucket and all its access points:
source run.sh \
  task=deploy \
  landscape=dev \
  bucket_user=true \
  profile=[aws_profile]

# If you want to also create an ec2 instance that runs a demo website that displays s3 content via this olap:
# NOTE: This will implicitly create the user as well.
source run.sh \
  task=deploy \
  landscape=dev \
  ec2=true \
  profile=[aws_profile]

# Combined example: creates ec2, user, and requires shib auth
source run.sh \
  task=deploy \
  landscape=dev \
  ec2=true \
  shib=true \
  host_name=[my.cn.known.by.the.idp] \
  profile=[aws_profile]
  
# Delete the app along with ALL created resources (except the code bucket)
source run.sh task=delete landscape=dev profile=[aws_profile]
```

NOTES:

- The HOST_NAME variable does not really make any difference to how any resources in the stack operate save for one small object lambda function adjustment to a specific s3 asset before it writes it out as a response. This file, index.htm, has image urls that are dynamically adjusted to reflect HOST_NAME.

- If SHIB=true, then the `*.kualitest.research.bu.edu` hosted zone is being "borrowed".
  You simply select a subdomain that is free and set HOST_NAME to it (ie: "mytest.kualitest.research.bu.edu).
  The apache hosted site on the ec2 instance only "listens" against that common name for the s3 asset requests.
  Thus, for traffic to be routed to the ec2 instance with that CN, an A record needs to be added into the hosted zone for kualitest:

  - Record Name: [HOST_NAME]
  - Type: A
  - Routing Policy: Simple
  - Value/Route traffic to: [Public IP address of the ec2 instance]

- You have a number of API methods for retrieving assets from the bucket:

  1. **Supporting access point:**

     ```
     aws s3api get-object --debug --key dilbert1.gif --bucket arn:aws:s3:us-east-1:770203350335:accesspoint/bu-wp-assets-olap-dev-ap dilbert1.gif
     ```

  2. **Object lambda access point (olap):**

     ```
     aws s3api get-object --debug --key dilbert1.gif --bucket arn:aws:s3-object-lambda:us-east-1:770203350335:accesspoint/bu-wp-assets-olap-olap dilbert1.gif
     ```

  3. **Demo web page:**
     When you deploy the stack, one of the outputs you will see is called "HostName".
     If you navigate with your browser to `https://${HostName}/index.htm`, you should see S3-originated content displayed.
     Each image that you see on the page is acquired through an access point.

  4. **Curl:**
     In order to get objects from the olap using curl, you will have to sign the request yourself.
     This is documented in the [companion git repository](https://github.com/whennemuth/bu-wp-assets-olap-client/blob/master/baseline/signer.md).

