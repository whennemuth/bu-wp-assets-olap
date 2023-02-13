const Authenticator = require('./Authenticator');
const Asset = require('./Asset');
const BasicContent = require('./transform/BasicContent')
const ErrorDecorator = require('./transform/ErrorDecorator');
const IndexPageDecorator = require('./transform/IndexPageDecorator');
const ThumbnailDecorator = require('./transform/ThumbnailDecorator');

String.prototype.equalsIgnoreCase = function (compareString) {
  if(compareString == null) return false;
  if(compareString == undefined) return false;
  return this.toUpperCase() === compareString.toUpperCase(); 
};
String.prototype.isTrue = function () {
  return this.equalsIgnoreCase('true');
}

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

    const authenticator = new Authenticator(
        event, 
        process.env.S3_REGION,
        process.env.SHIBBOLETH);

    if(authenticator.isAuthorized()) {

      this.getObjectKey = () => {
        var url = event.userRequest.url
        var host = event.userRequest.headers.Host;
        var key = url
          .replace(host, '')
          .replace(/^https?:\/\//i, '');
        if(key.startsWith('/')) {
          key = key.substring(1);
        }
        return key;
      }

      // TODO: If process.env.HOST_NAME is "lookup", then implement an SDK-based query that does the equivalent of curl -s http://169.254.169.254/latest/meta-data/public-hostname

      var asset = await new Asset(
        {
          region: process.env.S3_REGION || 'us-east-1',
          bucket: process.env.S3_BUCKET,
          event: event,
          ec2Hostname: process.env.HOST_NAME,
          key: this.getObjectKey(),
          transformer: new BasicContent()
            .decorate(ErrorDecorator)
            .decorate(IndexPageDecorator)
            .decorate(ThumbnailDecorator)
        }
      );

      asset.log();

      await asset.flush();

      return asset.respond();
    }
    else {
      return await authenticator.getUnauthorizedResponse();
    }
  }
  catch(e) {
    console.log(e, e.stack)
  }
}
