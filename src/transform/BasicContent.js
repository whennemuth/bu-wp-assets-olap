module.exports = function() {

  this.transformer = null;

  this.decorate = decorator => {
    this.transformer = new decorator(this.transformer || this);
    return this;
  }

  this.transform = (parms, data, error) => {
    if(this.transformer) {
      return this.transformer._transform(parms, data, error);
    }
    return this._transform(parms, data, error);
  }

  this._transform = (parms, data, error) => {
    if(data) {
      return data;
    }
    throw new Error('Empty or null data in response.');
  }
}