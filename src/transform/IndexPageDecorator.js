module.exports = function(decoratable) {

  this._transform = (parms, data, error) => {
    if( ! error && parms.key == 'index.htm') {
      return data.toString().replace(/\$\{HOSTNAME\}/g, parms.ec2Hostname);
    }
    return decoratable._transform(parms, data, error);
  }
}