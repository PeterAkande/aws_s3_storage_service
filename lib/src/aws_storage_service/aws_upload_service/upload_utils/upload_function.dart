import 'dart:async';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

Future<bool> fileUploader(
    {Function(int, int)? onSendProgress,
    Function(dynamic)? onSendComplete,
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

  BaseOptions options = BaseOptions(
      headers: headers,
      method: 'PUT',
      // responseType: ResponseType.bytes,
      contentType: 'application/octet-stream');

  final Dio dio = Dio(options);

  Completer<bool> uploadCompleter = Completer();

  print(bytesPayload.length);

  //////////////////////////////////////////////
  try {
    var resp = await http
        .put(
      Uri.parse(url),
      body: bytesPayload,
      headers: headers,
    )
        .then(
      (value) {
        if (value.statusCode == 200) {
          onSendComplete?.call(value);
          uploadCompleter.complete(true);
        } else {
          uploadCompleter.complete(false);
        }
      },
      onError: (error) {
        //An error occurred. Return it that the opetation was not successul
        uploadCompleter.complete(false);
      },
    );
  } catch (e) {
    //An error occurred, then return it that the upload was not successful
    uploadCompleter.complete(false);
  }

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

class MultipartRequest extends http.MultipartRequest {
  /// Creates a new [MultipartRequest].
  MultipartRequest(
    String method,
    Uri url, {
    required this.onProgress,
  }) : super(method, url);

  final void Function(int bytes, int totalBytes) onProgress;

  /// Freezes all mutable fields and returns a
  /// single-subscription [http.ByteStream]
  /// that will emit the request body.
  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) return byteStream;

    final total = contentLength;
    var bytes = 0;

    final t = StreamTransformer.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        bytes += data.length;
        onProgress.call(bytes, total);
        sink.add(data);
      },
    );
    final stream = byteStream.transform(t);
    return http.ByteStream(stream);
  }
}
