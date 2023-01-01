module.exports = function(decoratable) {

  this._transform = (parms, data, error) => {
    if( ! error && parms.key == 'index.htm') {
      return new Buffer(data.Body).toString()
        .replace(/\$\{DOMAIN_PREFIX\}/g, parms.apiId)
        .replace(/\$\{STAGE\}/g, parms.stage);
    }
    return decoratable._transform(parms, data, error);
  }
}