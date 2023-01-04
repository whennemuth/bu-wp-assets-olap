const AWS = require('aws-sdk');
const Asset = require('./Asset');
const BasicContent = require('./transform/BasicContent')
const ErrorDecorator = require('./transform/ErrorDecorator');
const IndexPageDecorator = require('./transform/IndexPageDecorator');
const ThumbnailDecorator = require('./transform/ThumbnailDecorator');

/**
 * This is the lambda function handler. It returns a response containing the base64 encoded s3 object 
 * that the api gateway will decode enroute back to the client. If the encoded object exceeds the size
 * limit for lambda return values, the a presigned url is returned as a redirect to the client to try
 * again directly more directly.
 * 
 * @param {*} event 
 * @param {*} context 
 * @returns 
 */
exports.GetAsset = async function(event, context) {
    try {
    
    console.log('------------------ EVENT ------------------')
    console.log(JSON.stringify(event, null, 2));
    console.log('-------------------------------------------')
    console.log('----------------- CONTEXT -----------------')
    console.log(JSON.stringify(context, null, 2));
    console.log('-------------------------------------------')
    
    var asset = await new Asset(
      {
        aws: AWS,
        region: process.env.S3_REGION,
        bucket: process.env.S3_BUCKET,
        key: event.pathParameters.proxy,
        apiId: event.requestContext.apiId,
        stage: event.requestContext.stage,
        maxBytes: 6000000,
        transformer: new BasicContent()
          .decorate(ErrorDecorator)
          .decorate(IndexPageDecorator)
          .decorate(ThumbnailDecorator)
      }
    );

    asset.log();

    if(asset.isTooBig()) {
      return asset.getPresignedUrlResponse(60);
    }

    return asset.response();
  }
  catch(e) {
    console.log(e, e.stack)
  }
}
