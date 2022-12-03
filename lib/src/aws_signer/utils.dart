import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';

const String service = 's3';
const String algorithm = 'AWS4-HMAC-SHA256';

class Utils {
  static stringToLowerCase(String word) {
    //Convert the word to lowercase
    return Utils.trimString(word).toLowerCase();
  }

  static String convertToHex(List<int> value) {
    return hex.encode(value);
  }

  static List<int> hmacSha256Hash(List<int> key, String value) {
    var hmacSha256 = Hmac(sha256, key);
    Digest encodedValue = hmacSha256.convert(value.codeUnits);

    return encodedValue.bytes;
  }

  static sha256Hash(List<int> value) {
    // return Hmac(sha256, value).convert(input);
    return sha256.convert(value).bytes;
  }

  static String trimString(String value) {
    //This method is to remove any trailing whitepaces or newlines in value passed
    return value.trim();
  }

  static uriEncode(String value) {
    //This function  is to encode the uri in the format the rest api better understands
    return Uri.encodeComponent(value);
  }

  static String generateDatetime() {
    //generate the datetime

    // return '20130524T000000Z';

    return DateTime.now()
        .toUtc()
        .toString()
        .replaceAll(RegExp(r'\.\d*Z$'), 'Z')
        .replaceAll(RegExp(r'[:-]|\.\d{3}'), '')
        .split(' ')
        .join('T');
  }

  static hashRequestPayload(String payload) {
    //This function is to hash the payload which is the request data

    return convertToHex(
      sha256Hash(
        utf8.encode(
          trimString(payload),
        ),
      ),
    );

    // return sha256Hash(
    //   utf8.encode(
    //     trimString(payload),
    //   ),
    // );
  }

  hextoBin(String value) {
    return hex.decode(value);
  }

  static String hashRequestPayloadBytes(List<int>? bytesPayload) {
    return convertToHex(
      sha256Hash(bytesPayload as List<int>),
    );

    // return sha256Hash(bytesPayload as List<int>);
  }
}

class Signature {
  final String signature;
  final String credentialScope;
  final String datetime;
  final String httpMethod;
  final String policy;

  Signature(this.credentialScope, this.datetime, this.httpMethod,
      this.signature, this.policy);
}

class HeaderElements {
  static const _awsSha256 = 'AWS4-HMAC-SHA256';
  static const _aws4request = 'aws4_request';
  static const _aws4 = 'AWS4';
  static const _xAmzDate = 'x-amz-date';
  static const _xAmzSecurityToken = 'x-amz-security-token';
  static const _host = 'host';
  static const _authorization = 'Authorization';
  static const _defaultContentType = 'application/json';
  static const _defaultAcceptType = 'application/json';
}
