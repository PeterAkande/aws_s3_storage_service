import 'dart:convert';
import 'utils.dart';

/// Signer For All Aws Requests
class AWSSigV4Signer {
  ///[secretKey] is gotten from the Aws Console
  final String secretKey;

  ///[accessKey] is gotten from the AWSconsole
  final String accessKey;

  ///[hostEndpoint] is the url of the bucket. e.g testbucket.s3.amazonaws.com
  final String hostEndpoint;

  ///[region] is the region where the bucket is created in
  final String region;
  Map<String, String> headers = {};

  AWSSigV4Signer(
      {required this.accessKey,
      required this.region,
      required this.hostEndpoint,
      required this.secretKey});

  ///Builds The Whole Authorzation Header of the request using Amazon SigV4
  ///
  ///Check [here](https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html#canonical-request) for more info
  ///[httpMethod] is the method of request. Either PUT or POST or GET
  ///[uri] is the path of the file or resource in aws
  ///[datetime] is an Iso8601([DateTime.now().toIso8601String()]) String of [DateTime]
  ///[unsignedPayload] is true for uploads, if the payload is to be unsigned
  ///[bytesPayload] is a [List] of bytes to be hashed and attached to the payload if [unsignedPayload] is false
  String buildAuthorizationHeader(String httpMethod, String uri,
      Map<String, String> queryParams, String datetime,
      {String requestPayload = '',
      List<int>? bytesPayload,
      bool unSignedPayload = false}) {
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

    Map<String, String> headers = constructHeader(datetime, hashedPayload);
    String signedHeaders = buildSignedHeader(headers);

    final canonicalRequest = buildCanonicalRequest(datetime, httpMethod, uri,
        requestPayload, headers, hashedPayload, queryParams, signedHeaders);

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

  ///Returns a map that would serve as the header if the request
  Map<String, String> constructHeader(String datetime, String hashedPayload) {
    //This method ois to construct the header, this is different from the whole authorization header.

    headers = {
      'host': hostEndpoint,
      'x-amz-date': datetime,
      'x-amz-content-sha256': hashedPayload,
    };

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
