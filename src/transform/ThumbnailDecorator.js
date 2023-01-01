module.exports = function(decoratable) {

  this.content = decoratable.content;
  this.data = decoratable.data;
  this.error = decoratable.error

  this._transform = (parms, content, error) => {
    if( ! error && false) {
      console.log('TODO: use sharp library to create thumbnail');
      // https://docs.aws.amazon.com/AmazonS3/latest/userguide/olap-writing-lambda.html#olap-getobject-response
    }
    return decoratable._transform(parms, content, error);
  }
}