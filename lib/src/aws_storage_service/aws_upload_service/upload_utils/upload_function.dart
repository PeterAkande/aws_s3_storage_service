import 'dart:async';

// import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

Future<bool> fileUploader(
    {Function(int, int)? onSendProgress,
    Function(dynamic, String versionId)? onSendComplete,
    required List<int> bytesPayload,
    required Map<String, String> headers,
    required String url}) async {
  ///onSendProgress gives the upload progress,
  ///onSendComplete is called when the upload is copmplete. It gives the response
  ///
  ///This function would be responsible for uploading a file to the the url.
  ///It returns a boolean if the upload was complete, false otherwise

  // headers.addAll({
  //   Headers.contentLengthHeader: bytesPayload.length.toString(),
  // });

  // BaseOptions options = BaseOptions(
  //     headers: headers,
  //     method: 'PUT',
  //     // responseType: ResponseType.bytes,
  //     contentType: 'application/octet-stream');

  // final Dio dio = Dio(options);

  Completer<bool> uploadCompleter = Completer();

  //////////////////////////////////////////////
  // try {
  var resp = await http
      .put(
    Uri.parse(url),
    body: bytesPayload,
    headers: headers,
  )
      .then(
    (value) {
      if (value.statusCode == 200) {
        onSendComplete?.call(value, value.headers['x-amz-version-id'] ?? '');
        uploadCompleter.complete(true);
      } else {
        print(value.body);
        uploadCompleter.complete(false);
      }
    },
    onError: (error) {
      print(error);
      //An error occurred. Return it that the opetation was not successul
      uploadCompleter.complete(false);
    },
  );

  // var request = MultipartRequest(
  //   'PUT',
  //   Uri.parse(url),
  //   onProgress: (int bytes, int total) {
  //     print('$bytes / $total');
  //   },
  // );

  // request.headers.addAll({
  //   'Content-Type': 'binary/octet-stream',
  // });

  // request.headers.addAll(headers);
  // request.files.add(
  //   await http.MultipartFile.fromBytes('first', bytesPayload),
  // );
  // final response = await request.send();

  // print(response.reasonPhrase);
  // print(response.statusCode);

  ///I dont know why dio is uploading a corrupt file.
  ///What could be the reason why?
  ///
  // dio.options.headers
  //     .addAll({Headers.contentLengthHeader: bytesPayload.length});

  // await dio.put(url, data: bytesPayload, onSendProgress: onSendProgress).then(
  //   (value) {
  //     onSendComplete?.call(value);
  //     uploadCompleter.complete(true);
  //   },
  //   onError: (error) {
  //     print(error);
  //     print(error.response);
  //     print(error.message);
  //     print(error.message);
  //     uploadCompleter.complete(false);
  //   },
  // );

  return uploadCompleter.future;
}
