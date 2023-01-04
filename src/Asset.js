const AssetThumbnail = require('./AssetThumbnail');

/**
 * This object represents an s3 object which is fetched from s3 asynchronously during constuction.
 * 
 * @param {Object} parms A parameter object
 * @param {Object} parms.aws The main aws sdk namespace object
 * @param {String} parms.region The region where exists the s3 bucket
 * @param {String} parms.apiId The ID of the api gateway to the lambda
 * @param {String} parms.stage The stage of the api gateway to the lambda 
 * @param {String} parms.key The key of the s3 object
 * @param {Number} parms.maxBytes The size in bytes of a base64-encoded s3 object when it exceeds lambdas response limit.
 * @param {Object} parms.transformer A decoratable object for singling out and modifying certain s3 objects before encoding based on event criteria.
 * @returns 
 */
module.exports = function(parms) {

  const S3 = new parms.aws.S3({region: parms.region});

  this.parms = parms;
  this.assetData = null;
  this.assetError = null;
  this.base64Bytes = null;
  this.contentType = null;

  this.log = () => {
    for(p in this.parms) {
      console.log(`${p} = ${this.parms[p]}`);
    }
  }

  this.error = () => {
    return assetError;
  }

  /**
   * @returns The success response containing the base64 encoded s3 object.
   */
  this.response = () => {
    return {
      statusCode: 200,
      headers: { 'Content-Type': this.contentType },
      body: this.getBase64(),
      isBase64Encoded: true
    };
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
   * Takes in the content of the s3 object and outputs the base64 equivalent.
   * @returns The base64 encoded content.
   */
  this.getBase64 = () => {
    var content = this.getContent(this.assetData, this.assetError);
    if(content.base64) {
      if(content.contentType) {
        this.contentType = content.contentType;
      }
      return content.base64;
    }
    return new Buffer(content).toString('base64');
  }

  this.getPresignedUrl = expireSeconds => {
    return S3.getSignedUrl('getObject', { Bucket: this.parms.bucket, Key: this.parms.key, Expires: expireSeconds });
  }

  /**
   * The s3 object exceeds the response size limit of lambda, so return a redirect to the s3 object url,
   * presigned to allow direct access.
   * @param {*} expireSeconds The duration the presigned url is good for.
   * @returns A presigned url to the s3 object
   */
  this.getPresignedUrlResponse = expireSeconds => {
    return {
      statusCode: 302,
      headers: { 'Location': this.getPresignedUrl(expireSeconds) }
    }
  }

  /**
   * Lambda has a 6MB limit to its response payload.
   * @returns The encoded s3 object content exceeds the limit.
   */
  this.isTooBig = () => {
    return this.base64Bytes > this.parms.maxBytes;
  }

  /**
   * Perform the initial acquisition of the s3 object as part of the construction of this object.
   * A promise is returned to allow for asynchronous instantiation: var asset = await new Asset(parms); 
   */
  return new Promise (
    (resolve) => {
      try {
        resolve((async () => {
          await S3.getObject({ Bucket: this.parms.bucket, Key: this.parms.key }).promise()
            .then(data => {
              this.assetData = data;
              this.contentType = data.ContentType;
              this.base64Bytes = 4 * Math.ceil(data.ContentLength / 3.0);        
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
            })
          return this;
        })());
      }
      catch(err) {
        throw(err);
      }      
    }
  );
}