const { S3 } = require('aws-sdk');

module.exports = function(asset) {

  const s3 = new S3({region: asset.parms.region});

  this.data = null;

  this.requested = () => {
    return /^.+?__thumbnail\.[^\.]+$/i.test(asset.parms.key);
  }

  this.notFound = () => {
    if(asset.response.ErrorCode) {
      if(asset.response.ErrorCode && asset.response.ErrorCode == 'NoSuchKey') {
        return true;
      }
    }
    return false;
  }

  this.getBaseImageName = () => {
    return replaceLast('__thumbnail', '', asset.parms.key);
  }
  
  this.baseImageExists = async () => {
    var params = {
      Bucket: asset.parms.bucket, 
      Key: this.getBaseImageName()
    };
    return new Promise(
      (resolve) => {
        try {
          resolve((async () => {
            await s3.headObject(params).promise()
              .then(data => {
                /*
                data = {
                AcceptRanges: "bytes", 
                ContentLength: 3191, 
                ContentType: "image/jpeg", 
                ETag: "\"6805f2cfc46c0f04559748bb039d69ae\"", 
                LastModified: <Date Representation>, 
                Metadata: {
                }, 
                VersionId: "null"
                }
                */
                console.log(data);
              })
              .catch(err => {
                console.log(err, err.stack);
                throw(err);
              })
          })());
        }
        catch(e) {
          console.log(e, e.stack);
          throw(e);
        }
      }
    );
  }

  this.getResizedData = async () => {
    var baseImage = this.getBaseImageName();
    // TODO: Use sharp library to resize the image and return its data.
    return this.data;
  }

  this.createAndPutInBucket = async () => {
    getResizedData();
    // TODO: complete this.
  }

  this.replaceLast = (find, replace, string) => {
    var lastIndex = string.lastIndexOf(find);    
    if (lastIndex === -1) {
        return string;
    }    
    var beginString = string.substring(0, lastIndex);
    var endString = string.substring(lastIndex + find.length);    
    return beginString + replace + endString;
  }
}