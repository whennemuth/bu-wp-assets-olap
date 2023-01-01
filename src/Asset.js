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

  this.assetData = null;
  this.assetError = null;
  this.base64Bytes = null;
  this.contentType = null;

  this.log = () => {
    for(p in parms) {
      console.log(`${p} = ${parms[p]}`);
    }
  }

  this.error = () => {
    return assetError;
  }

  this.response = () => {
    return {
      statusCode: 200,
      headers: { 'Content-Type': this.contentType },
      body: this.getBase64(),
      isBase64Encoded: true
    };
  }

  this.getContent = (content, error) => {
    if(parms.transformer) {
      return parms.transformer.transform(parms, content, error)
    }
    return content;
  };

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
    return S3.getSignedUrl('getObject', { Bucket: parms.bucket, Key: parms.key, Expires: expireSeconds });
  }

  this.getPresignedUrlResponse = expireSeconds => {
    return {
      statusCode: 302,
      headers: { 'Location': this.getPresignedUrl(expireSeconds) }
    }
  }

  this.isTooBig = () => {
    return this.base64Bytes > parms.maxBytes;
  }

  return new Promise (
    (resolve) => {
      try {
        resolve((async () => {
          await S3.getObject({ Bucket: parms.bucket, Key: parms.key }).promise()
            .then(data => {
              this.assetData = data;
              this.contentType = data.ContentType;
              this.base64Bytes = 4 * Math.ceil(data.ContentLength / 3.0);        
            })
            .catch(err => {
              this.assetError = err;
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