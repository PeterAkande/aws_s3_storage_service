import 'dart:convert';

import '../aws_storage_service.dart';
import 'utils.dart';

//Make this client a singleton in the flutter code.
class AWSSigV4Signer {
  //The kind of request targeted here is the path styled requests
  final String secretKey;
  final String accessKey;
  final String hostEndpoint;
  Map<String, String> headers = {};
  String? bucketId;

  AWSSigV4Signer(
      {required this.accessKey,
      required this.hostEndpoint,
      required this.secretKey});

  Signature buildSignatureObject(
    String httpMethod,
    String uri,
    Map<String, String> queryParams,
    String datetime,
  ) {
    //Build the signature according to the amazon S4 signature;
    /*Check out 
    https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-authentication-HTTPPOST.html for the more understanding of
    This function and the functions called here.*/

    final credentialScope =
        '$accessKey/${datetime.substring(0, 8)}/$region/s3/aws4_request'; //datetime.substring(0,8) is used because only the date is needed.
    final signingKey = buildSigningKey(datetime);

    final String policy = buildPolicy(datetime, credentialScope);
    final String stringToSign = buildEncodedPolicy(policy);

    final String signature = buildSignature(signingKey, stringToSign);

    return Signature(signature, credentialScope, datetime, httpMethod, policy);
  }

  String buildAuthorizationHeader(String httpMethod, String uri,
      Map<String, String> queryParams, String datetime,
      {String requestPayload = '',
      List<int>? bytesPayload,
      bool unSignedPayload = false}) {
    //Build the authorization according to the amazon S4 signature;

    /*Check out 
    https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html#canonical-request for the more understanding of
    This function and the function called here.*/
    String hashedPayload = '';
    if (!unSignedPayload) {
      if (bytesPayload != null) {
        hashedPayload = Utils.hashRequestPayloadBytes(bytesPayload);
      } else {
        hashedPayload = Utils.hashRequestPayload(requestPayload);
      }
    } else {
      hashedPayload = 'UNSIGNED-PAYLOAD';
    }

    // hashedPayload = 'UNSIGNED-PAYLOAD';

    Map<String, String> headers = constructHeader(datetime, hashedPayload);
    String signedHeaders = buildSignedHeader(headers);

    final canonicalRequest = buildCanonicalRequest(datetime, httpMethod, uri,
        requestPayload, headers, hashedPayload, queryParams, signedHeaders);

    print(canonicalRequest);

    final credentialScope =
        '${datetime.substring(0, 8)}/$region/s3/aws4_request'; //datetime.substring(0,8) is used because only the date is needed.

    final String stringToSign =
        buildStringToSign(canonicalRequest, datetime, credentialScope);

    final signingKey = buildSigningKey(datetime);
    final String signature = buildSignature(signingKey, stringToSign);

    final String authorizationHeader =
        buildFinalSigningInformation(credentialScope, signedHeaders, signature);

    return authorizationHeader;
  }

  buildEncodedPolicy(policy) {
    return base64.encode(utf8.encode(policy));
  }

  buildPolicy(String credentialScope, String datetime) {
    final String policy = '''{
        "conditions":[
          {"x-amz-credential": "$credentialScope"},
          {"x-amz-algorithm": "AWS4-HMAC-SHA256"},
          {"x-amz-date": "$datetime" },
        ]
      }
''';

    return policy;
  }

  buildFinalSigningInformation(
      String credentialScope, String signedHeaders, String signature) {
    final String signingInfo =
        '$algorithm Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    return signingInfo;
  }

  String buildCanonicalRequest(
      String datetime,
      String httpMethod,
      String uri, //This uri is the path to required object
      String requestPayload, //Request payload is the body of the request.
      Map<String, String> headers,
      String hashedPayload,
      Map<String, String> queryParams,
      String signedHeaders) {
    String canonicalUri = buildCanonicalUri(uri);
    String canonicalQueryString = buldCanonicalQueryString(queryParams);
    String canonicalHeaders = buildCanonicalizedAmzHeaders(headers);

    String canonicalRequest =
        '$httpMethod\n$canonicalUri\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$hashedPayload';

    return canonicalRequest;
  }

  String buldCanonicalQueryString(Map<String, String>? subResources) {
    //subResources == QueryParams
    if (subResources == null || subResources.isEmpty) {
      //I dont thinlk i would be using this block though since the calls are restricted and does not encompass all of the possible usage of
      //Amazon S3
      //This is a special case where no query paramenters are given.

      return '';
    }

    final sortedQueryParams = []; //This is a list to store the query params
    subResources.forEach((key, value) {
      sortedQueryParams.add(key);
    });
    sortedQueryParams
        .sort(); //Sort the query params since the AWS rest api require the subresources to be lexicographically sorted.

    final canonicalQueryStrings = [];
    for (var key in sortedQueryParams) {
      canonicalQueryStrings.add(
          '${Uri.encodeComponent(key)}=${Uri.encodeQueryComponent(subResources[key]!).replaceAll('+', "%20")}');
    }

    return canonicalQueryStrings.join('&');
  }

  String buildCanonicalUri(String path) {
    return Uri.encodeComponent(path)
        .replaceAll(RegExp('%2F'), '/')
        .replaceAll('(', '%28')
        .replaceAll(')', '%29');
  }

  String buildCanonicalizedAmzHeaders(Map<String, String?> headers) {
    //For the headers, the ones that are very important are host and x_amz_date, content-type, x-amz-content-sha256
    final sortedKeys = [];
    headers.forEach((property, _) {
      sortedKeys.add(property);
    });

    var canonicalHeaders = '';
    sortedKeys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (var property in sortedKeys) {
      canonicalHeaders += '${property.toLowerCase()}:${headers[property]}\n';
    }

    return canonicalHeaders;
  }

  Map<String, String> constructHeader(String datetime, String hashedPayload) {
    //This method ois to construct the header, this is different from the whole authorization header.

    headers = {
      'host': hostEndpoint,
      'x-amz-date': datetime,
      'x-amz-content-sha256': hashedPayload,
      // 'date': 'Fri, 24 May 2013 00:00:00 GMT',
      // 'x-amz-storage-class': 'REDUCED_REDUNDANCY'
    };

    // headers = {

    //   'host': hostEndpoint as String,
    //   'x-amz-date': datetime,
    //   'x-amz-content-sha256': hashedPayload
    // };
    // 'x-amz-acl': 'private', 'x-amz-security-token

    return headers;
  }

  String buildStringToSign(
      String canonicalRequest, String datetime, String scope) {
    final hashedCanonicalRequest = Utils.hashRequestPayload(canonicalRequest);

    String stringToSign =
        '$algorithm\n$datetime\n$scope\n$hashedCanonicalRequest';

    return stringToSign;
  }

  buildSignedHeader(Map<String, String> header) {
    //This method is to return the header keys in the form x-amz-date;host;blablabla

    final sortedKeys = [];
    header.forEach((property, _) {
      sortedKeys.add(Utils.stringToLowerCase(property));
    });

    sortedKeys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    String signedHeaders = sortedKeys.join(';');

    return signedHeaders;
  }

  List<int> buildSigningKey(
    String datetime,
  ) {
    //https://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html

    final kDate = Utils.hmacSha256Hash(
        'AWS4${Utils.trimString(secretKey)}'
            .codeUnits, // create a sha256 hash of the Secret key
        Utils.trimString(datetime).substring(0, 8));
    final kRegion = Utils.hmacSha256Hash(kDate, Utils.trimString(region));
    final kService = Utils.hmacSha256Hash(kRegion, Utils.trimString(service));

    final List<int> kSigning = Utils.hmacSha256Hash(kService, 'aws4_request');

    return kSigning;
  }

  buildSignature(List<int> signingKey, String stringToSign) {
    final signature = Utils.convertToHex(
      Utils.hmacSha256Hash(signingKey, Utils.trimString(stringToSign)),
    );

    return signature;
  }
}
