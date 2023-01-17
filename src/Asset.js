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

  this.parms = parms;
  this.assetData = null;
  this.assetError = null;
  this.contentType = null;

  const { getObjectContext } = parms.event;
  const { outputRoute, outputToken, inputS3Url } = getObjectContext;

  this.log = () => {
    for(p in this.parms) {
      console.log(`${p} = ${this.parms[p]}`);
    }
  }

  this.error = () => {
    return assetError;
  }

  /**
   * @returns A success response.
   */
  this.response = () => {
    return {
      statusCode: 200
    };
  }

  /**
   * Write the object content back out in the response.
   * @returns 
   */
  this.flush = async () => {
    return await s3.writeGetObjectResponse({
      RequestRoute: outputRoute,
      RequestToken: outputToken,
      Body: this.assetData,
    }).promise();
  }

  /**
   * Get the byte content of the s3 object as potentially modified by the transformer.
   * @param {*} content The untransformed s3 object
   * @param {*} error Any error encountered in fetching the object from s3
   * @returns 
   */
  this.getContent = (content, error) => {
    if(this.parms.transformer) {
      return this.parms.transformer.transform(this.parms, content, error)
    }
    return content;
  };


  /**
   * Perform the initial acquisition of the s3 object as part of the construction of this object.
   * A promise is returned to allow for asynchronous instantiation: var asset = await new Asset(parms); 
   */
  return new Promise (
    (resolve) => {
      try {
        resolve((async () => {

          await axios.get(inputS3Url, { responseType: "arraybuffer" })
            .then(presignedResponse => {
              this.assetData = presignedResponse.data;
            })
            .catch(async err => {              
              this.assetError = err;
              var thumbnail = new AssetThumbnail(this);
              if(thumbnail.requested() && thumbnail.notFound()) {
                if(await thumbnail.baseImageExists()) {
                  if(await thumbnail.createAndPutInBucket()) {
                    return new Asset(this.parms);
                  }
                }
              }
            });

          return this;
        })());
      }
      catch(err) {
        throw(err);
      }      
    }
  );
}