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

You can run the SAM commands *(validate, package, deploy, delete)* by themselves, or make use of some shortcut script (run.sh) that:

- Includes command parameters dealing with default names and parameters not available for sam toml config files.
- Auto-populates the assets bucket with content upon creation and empties it so it can be deleted along with other resources made during stack creation.

There are two options for stack creation / app deployment

1. **OLAP only**
   Create the bucket, lambda, and olap:

   ```
   # Build, package and deploy the app (runs both a sam build and deploy)
   source run.sh task=deploy landscape=dev profile=[aws_profile]
   
   # Delete the app along with ALL created resources (except the code bucket)
   source run.sh task=delete landscape=dev profile=[aws_profile]
   ```

   The lambda will assume a default HOST_NAME environment variable of "local-ol", but you can override this:

   ```
   source run.sh task=deploy landscape=dev host_name=my.custom.hostname profile=[aws_profile]
   ```
   
   *NOTE: The HOST_NAME variable does not really make any difference to how any resources in the stack operate save for one small object lambda function adjustment to a specific s3 asset before it writes it out as a response. This file, index.htm, has image urls that are dynamically adjusted to reflect HOST_NAME.*
   
   Examples of using the ap/olap to get content from the bucket:

   ```
   # Get an object from the bucket using the supporting access point:
   aws s3api get-object --debug --key dilbert1.gif --bucket arn:aws:s3:us-east-1:770203350335:accesspoint/bu-wp-assets-olap-dev-ap dilbert1.gif
   
   # Get an object from the bucket using the olap directly:
   aws s3api get-object --debug --key dilbert1.gif --bucket arn:aws:s3-object-lambda:us-east-1:770203350335:accesspoint/bu-wp-assets-olap-dev-olap dilbert1.gif
   ```
   
   In order to get objects from the olap using curl, you will have to sign the request yourself. This is documented in the [companion git repository](https://github.com/whennemuth/bu-wp-assets-olap-client/blob/master/baseline/signer.md)
   
2. **OLAP with ec2 client**
   Create the bucket, lambda, olap, AND an ec2 instance that runs an apache proxy to the olap:

   ```
   # Build, package and deploy the app with an ec2 (runs both a sam build and deploy)
   
      # a) The ec2 implements shib authentication, and uses an elastic IP
        source run.sh task=deploy landscape=dev ec2=true shib=true profile=[aws_profile] 
       
      # b) The ec2 does NOT implement shib authentication, but uses a custom hostname (route53 involved?)
        source run.sh task=deploy landscape=dev ec2=true host_name=qa.kualitest.research.bu.edu profile=[aws_profile]
   
   # Delete the app along with ALL created resources (except the code bucket)
   source run.sh task=delete landscape=dev profile=[aws_profile]
   ```

### Demo webpage:

When you run `sam deploy`, one of the stack outputs you will see is called "Webpage". 
This provides a URL you can navigate to with your browser to see S3-originated content displayed.

