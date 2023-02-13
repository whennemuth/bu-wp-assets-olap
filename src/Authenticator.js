
module.exports = function(event, region, shib) {

  const { S3 } = require('aws-sdk');
  const { getObjectContext } = event;
  const { url, headers } = event.userRequest;
  const { outputRoute, outputToken } = getObjectContext;
  
  const useShib = () => "true".equalsIgnoreCase(shib);
  
  const headerExists = header => {
    return Object
      .keys(headers)
      .includes(header);
  }

  const getUserName = () => {
    return headers["buPrincipalNameID"];
  }

  const buPrincipalFound = () => headerExists('buPrincipalNameID');

  const eppnFound = () => headerExists('eppn');
  
  const shibCookieFound = () => {
    if(headerExists('Cookie')) {
      return headers['Cookie'].startsWith('_shibsession_');
    }
    return false;
  }

  const sufficientShibbolethData = () => shibCookieFound() && buPrincipalFound() && eppnFound();

  const isRestrictedAsset = () => {
    return url.split("/").includes('__restricted');
  }

  /**
   * @returns A boolean indicating if the folder containing the restricted asset matches the prinicple name shibboleth header.
   */
  const isPersonalAsset = () => {
    let parts = url.split("/");
    let folderOwner = parts[parts.indexOf('__restricted') + 1]
    return folderOwner == getUserName();
  }

  const isSuperUser = () => {
    return getUserName() == 'wrh'
  }
  
  this.isAuthorized = () => {

    console.log('Checking authorization...');

    if( ! useShib()) return true;
    console.log('Using shibboleth');

    if( ! isRestrictedAsset()) return true;
    console.log('Restricted asset being requested');

    if( ! sufficientShibbolethData()) return false;
    console.log('Sufficient shibboleth data provided');

    if(isSuperUser()) return true;
    console.log('Not the superuser');

    if(isPersonalAsset()) {
      console.log('Is a personal asset');
      return true;
    }

    console.log('Not a personal asset');
    return false;
  }

  this.getUnauthorizedResponse = async () => {
    const s3 = new S3({region: region});

    console.log("NoShibbolethHeadersFound: The request is not authorized")
    return await s3.writeGetObjectResponse({
      RequestRoute: outputRoute,
      RequestToken: outputToken,
      StatusCode: 403,
      ErrorCode: "NoShibbolethHeadersFound",
      ErrorMessage: "The request is not authorized.",
    }).promise();
  }
}