const AWS = require('aws-sdk');
const Error = require('./S3RequestHandlerError');

exports.Authorize = function(event, context, callback) {
  try {
    
    console.log('------------------ EVENT ------------------')
    console.log(JSON.stringify(event, null, 2));
    console.log('-------------------------------------------')
    console.log('----------------- CONTEXT -----------------')
    console.log(JSON.stringify(context, null, 2));
    console.log('-------------------------------------------')

    const region = process.env.S3_REGION;
    const bucket = process.env.S3_BUCKET;
    const key = decodeURI( event.pathParameters.proxy );
    const s3 = new AWS.S3({region: region});

    console.log('region = ' + region);
    console.log('bucket = ' + bucket);
    console.log('key = ' + key);

    return s3.getObject(
      { Bucket: bucket, Key: key },
      function(err, data) {

        if (err) {
          // Serve up a mushroom cloud
          var resp = {
            statusCode: 200,
            headers: { 'Content-Type': 'image/jpeg' },
            body: Error.getErrorImage64(),
            isBase64Encoded: true
          };
          console.log(err, err.stack)
        }
        else {
          // Serve up the requested s3 content
          var resp = {
            statusCode: 200,
            headers: { 'Content-Type': data.ContentType },
            body: new Buffer(data.Body).toString('base64'),
            isBase64Encoded: true
          };
        }

        callback(null, resp);
      }
    );
  }
  catch(e) {
    console.log(e, e.stack)
  }
}
