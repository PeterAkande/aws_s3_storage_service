import 'dart:async';
import 'dart:io';

import 'package:aws_storage_service/src/aws_signer/aws_sigv4_signer.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_download_service/download_file_utils/download_file_config.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../aws_signer/utils.dart';
import 'download_file_utils/dio_download_manager.dart';

///[DownloadFile] handles the downlood process
class DownloadFile {
  //This class would be incharge of downloading a file.
  //It would:
  //1.) Expose a stream that gives the download progress.
  //2.) Have an error callback function.
  //3.) Have the resume download support.

  ///The [DownloadFileConfig]. It contains settings that governs the download process
  final DownloadFileConfig config;
  late Map<String, String> _header;

  ///Cancel token used to cancel downloads. Type [CancelToken]
  CancelToken _cancelToken = CancelToken();

  ///Stream to give the download progress of the file
  ///
  ///Gives the latest progress when a new listener is attached
  final BehaviorSubject<List<int>> _downloadProgress =
      BehaviorSubject.seeded([0, 0]);

  ///callback to notify the current upload progress. Similar to [_downloadProgress]
  final Function(int totalDownloaded, int totalSize)? onRecieveProgress;

  ///Callback when an error occures
  final Function(String errorMessage, int? statusCode)? errorCallback;

  DownloadFile(
      {required this.config, this.onRecieveProgress, this.errorCallback});

  Stream<List<int>> get downloadProgress =>
      _downloadProgress.asBroadcastStream();

  ///[prepareDownload] initialize the needed parameters that are needed for the download operation
  Future<bool> prepareDownload() async {
    // Todo: Take into consideration the calculation of headers for Cloudfront
    // Signing

    String datetime = Utils.generateDatetime();
    final Completer<bool> preparationCompleter = Completer();

    AWSSigV4Signer signer = AWSSigV4Signer(
        region: config.credentailsConfig.region,
        accessKey: config.credentailsConfig.accessKey,
        secretKey: config.credentailsConfig.secretKey,
        hostEndpoint: config.credentailsConfig
            .host); // Create the AWS Signer to be used to sign the AWS Request

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
            'File to be resumed does not exist. Please set resume download to false to download a new file',
            404);

        if (config.continueDownloadIfFileDoesNotExist) {
          config.resumeDownload = false;
          preparationCompleter.complete(true);
          return true; // Not needed but stops this the parent block here.
        }

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

  ///[download] starts the download process. It starts to download the file
  Future<bool> download() async {
    final Completer<bool> downloadCompleter = Completer();

    late String uploadUrl;

    if (config.credentailsConfig.clourFrontHostUrl.isEmpty) {
      uploadUrl =
          'https://${config.credentailsConfig.host}/${Uri.encodeComponent(config.url)}';
    } else {
      uploadUrl =
          'https://${config.credentailsConfig.clourFrontHostUrl}/${Uri.encodeComponent(config.url)}';
    }

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
          if (error.type == DioErrorType.cancel) {
            //It was cancelled using the cancel token
            errorCallback?.call('Dio cancel Error', 400);
          } else {
            errorCallback?.call(error.toString(), error.response.statusCode);
          }

          dispose();
          downloadCompleter.complete(false);
        },
      );
    } catch (error) {
      if ((error as dynamic).type == DioErrorType.cancel) {
        //It was cancelled using the cancel token
        errorCallback?.call('Dio cancel Error', 400);
      } else {
        errorCallback?.call(error.toString(), 400);
      }

      dispose();
      downloadCompleter.complete(false);
    }

    return downloadCompleter.future;
  }

  ///Pauses the download
  void pauseDownload() {
    _cancelToken.cancel();

    _cancelToken = CancelToken();
  }

  void dispose() {
    //This closes the Stream of the download progress
    _downloadProgress.close();
  }
}
