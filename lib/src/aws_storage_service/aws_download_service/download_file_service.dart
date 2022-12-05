import 'dart:async';
import 'dart:io';

import 'package:aws_storage_service/src/aws_signer/aws_sigv4_signer.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_download_service/download_file_utils/download_file_config.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../aws_signer/utils.dart';
import 'download_file_utils/dio_download_manager.dart';

class DownloadFile {
  //This class would be incharge of downloading a file.
  //It would:
  //1.) Expose a stream that gives the download progress.
  //2.) Have an error callback function.
  //3.) Have the resume download support.

  final DownloadFileConfig config;
  late Map<String, String> _header;

  //The cancel token would be useful for pausing uploads.
  CancelToken _cancelToken = CancelToken();

  final BehaviorSubject<List<int>> _downloadProgress =
      BehaviorSubject.seeded([0, 0]);

  //This would be the function that would be called as the upload is going on.
  final Function(int totalDownloaded, int totalSize)? onRecieveProgress;
  final Function(String errorMessage)? errorCallback;

  DownloadFile(
      {required this.config, this.onRecieveProgress, this.errorCallback});

  Stream<List<int>> get downloadProgress =>
      _downloadProgress.asBroadcastStream();

  Future<bool> prepareDownload() async {
    //This function would initialize the needed parameters that are needed for the download operation
    //If the preparation is successful, return true and false if it is otherwise
    String datetime = Utils.generateDatetime();
    final Completer<bool> preparationCompleter = Completer();

    AWSSigV4Signer signer = AWSSigV4Signer(
        region: config.credentailsConfig.region,
        accessKey: config.credentailsConfig.accessKey,
        secretKey: config.credentailsConfig.secretKey,
        hostEndpoint: config.credentailsConfig.host);

    final authorizationHeader = signer.buildAuthorizationHeader(
        'GET', '/${config.url}', {}, Utils.trimString(datetime),
        requestPayload: '');

    _header = signer.headers;
    _header['Authorization'] = authorizationHeader;

    if (config.resumeDownload) {
      File fileTobeResumed = File(config.downloadPath);
      if (!fileTobeResumed.existsSync()) {
        //Complete the function with false.
        errorCallback?.call(
            'File to be resumed does not exist. Please set resume download to false to download a new file');

        preparationCompleter.complete(false);
      } else {
        // print('The range is ${'bytes=${fileTobeResumed.lengthSync()}-'}');
        _header['range'] = 'bytes=${fileTobeResumed.lengthSync()}-';
        preparationCompleter.complete(true);
      } //
    } else {
      preparationCompleter.complete(true);
    }

    return preparationCompleter.future;
  }

  Future<bool> download() async {
    //This function would be incharge of downloading a file.
    //If an error occurs, it returns false.
    //If the download was successful, it returns true.

    final Completer<bool> downloadCompleter = Completer();

    String uploadUrl =
        'https://${config.credentailsConfig.host}/${Uri.encodeComponent(config.url)}';

    Options options = Options(headers: _header);

    try {
      await DioDownloadManager().download(uploadUrl, config.downloadPath,
          onReceiveProgress: ((count, total) {
        _downloadProgress.add([count, total]);
        onRecieveProgress?.call(count, total);
      }),
          cancelToken: _cancelToken,
          options: options,
          deleteOnError: false,
          resumeDownload: config.resumeDownload).then(
        (value) {
          dispose();
          downloadCompleter.complete(true);
        },
        onError: (error) {
          // print(error.type);
          // print(error);
          if (error.type == DioErrorType.cancel) {
            //It was cancelled using the cancel token
            errorCallback?.call('Dio cancel Error');
          } else {
            errorCallback?.call(error.toString());
          }

          dispose();
          downloadCompleter.complete(false);
        },
      );
    } catch (error) {
      if ((error as dynamic).type == DioErrorType.cancel) {
        //It was cancelled using the cancel token
        errorCallback?.call('Dio cancel Error');
      } else {
        errorCallback?.call(error.toString());
      }

      dispose();
      downloadCompleter.complete(false);
    }

    return downloadCompleter.future;
  }

  void pauseDownload() {
    _cancelToken.cancel();

    _cancelToken = CancelToken();
  }

  void dispose() {
    //This closes the Stream of the download progress
    _downloadProgress.close();
  }
}
