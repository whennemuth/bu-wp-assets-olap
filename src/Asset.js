const { S3 } = require('aws-sdk');
const axios = require('axios').default;
const AssetThumbnail = require('./AssetThumbnail');

/**
 * This object represents an s3 object which is fetched from s3 asynchronously during constuction.
 * 
 * @param {Object} parms A parameter object
 * @param {Object} parms.event A getObject event passed into the object lambda handler via its access point.
 * @param {String} parms.region The region where exists the s3 bucket
 * @param {String} parms.ec2Hostname The hostname used that identified the asset being requested before it gets proxied to an access point url.
 * @param {String} parms.key The key of the s3 object
 * @param {Object} parms.transformer A decoratable object for singling out and modifying certain s3 objects before encoding based on event criteria.
 * @returns 
 */
module.exports = function(parms) {

  const s3 = new S3({region: parms.region});
  const { getObjectContext } = parms.event;
  const { outputRoute, outputToken, inputS3Url } = getObjectContext;


  this.parms = parms;

  this.log = () => {
    for(p in parms) {
      console.log(`${p} = ${parms[p]}`);
    }
  }

  /**
   * @returns A success response.
   */
  this.respond = () => {
    return {
      statusCode: 200,
    };
  }

  this.response = {
    RequestRoute: outputRoute,
    RequestToken: outputToken,
  };

  /**
   * Write the object content back out in the response.
   * @returns 
   */
  this.flush = async () => {
    return await s3.writeGetObjectResponse(this.response).promise();
  }

  /**
   * Get the byte content of the s3 object as potentially modified by the transformer.
   * @param {*} content The untransformed s3 object
   * @param {*} error Any error encountered in fetching the object from s3
   * @returns 
   */
  this.getContent = (content, error) => {
    if(parms.transformer) {
      try {
        return parms.transformer.transform(parms, content, error);
      }
      catch(e) {
        console.log(`Error transforming content: ${e}`);
        this.response.StatusCode = 500;
        this.response.ErrorCode = 'TransformError';
        this.response.ErrorMessage = `${e.name} - ${e.message}`;
        return null;
      }
    }
    return content;
  };

  let asset = this;

  /**
   * Perform the initial acquisition of the s3 object as part of the construction of this object.
   * A promise is returned to allow for asynchronous instantiation: var asset = await new Asset(parms); 
   */
  return new Promise (
    (resolve) => {
      resolve((async () => {
        await axios.get(inputS3Url, { responseType: "arraybuffer" })
          .then(presignedResponse => {
            console.log(`RESPONSE OK`);
            asset.response.StatusCode = presignedResponse.status;
            asset.response.Body = asset.getContent(presignedResponse.data, null);
            asset.response.ContentType = presignedResponse.headers['content-type'];
          })
          .catch(async err => {
            // If a thumbnail was requested but doesn't exist, so create and return it if the base image exists.
            let thumbnail = new AssetThumbnail(asset); 
            if(thumbnail.requested() && thumbnail.notFound()) {
              if(await thumbnail.baseImageExists()) {
                await thumbnail.createAndPutInBucket();
                asset.response.Body = thumbnail.getResizedData();
              }
              else {
                asset.response.StatusCode = 404;
                asset.response.ErrorCode = "BaseAssetNotFound";
                asset.response.ErrorMessage = "No such thumbnail and no such base image.";
              }
            }
            else {
              console.log(`Error in resolved promise: ${err}`);
              if((new String("false")).equalsIgnoreCase(process.env.ERROR_IMAGE)) {
                asset.response.StatusCode = err.response.status;
                asset.response.ErrorCode = err.response.statusText.replace(/\x20/g, '');
                asset.response.ErrorMessage = encodeURIComponent(err.response.data.toString());
              }
              else {
                asset.response.StatusCode = 200;
                var errImg = asset.getContent(null, err);
                asset.response.Body = errImg.buffer();
                asset.response.ContentType = errImg.contentType;
              }       
              // asset.getContent(err.response.data);
            }
          });

        return this;
      })());
    }
  );
}