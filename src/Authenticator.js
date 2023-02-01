
module.exports = function(event, region) {

  const { S3 } = require('aws-sdk');
  const { userRequest, getObjectContext } = event;
  const { outputRoute, outputToken } = getObjectContext;
  
  this.shibbolethTokenFound = () => {
    return true;

    // return Object
    //   .keys(userRequest.headers)
    //   .includes("ShibbolethToken");
  }

  this.getUnauthorizedResponse = async () => {
    const s3 = new S3({region: region});

    return await s3.writeGetObjectResponse({
      RequestRoute: outputRoute,
      RequestToken: outputToken,
      StatusCode: 403,
      ErrorCode: "NoShibbolethTokenFound",
      ErrorMessage: "The request is not authorized.",
    }).promise();
  }
}