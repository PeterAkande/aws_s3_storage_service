import 'dart:async';

import 'package:aws_storage_service/src/aws_signer/aws_sigv4_signer.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_template.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_utils/upload_object_config.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../aws_signer/utils.dart';

///This handles the upload of an object, e.g Strings or text objects in general
class UploadObject extends UploadTask {
  final UploadTaskConfig config;

  //BehaviourSubject is used so that the latest value broadcasted to any new subscriber
  final BehaviorSubject<List<int>> _uploadProgress =
      BehaviorSubject.seeded([0, 0]);

  /// uploadProgress returns a Stream of the currently upload progress.
  @override
  Stream<List<int>> get uploadProgress => _uploadProgress.asBroadcastStream();

  ///[onUploadComplete] is called when the upload has been completed. It gives the response and teh version id
  final Function(dynamic response, String versionId)? onUploadComplete;

  UploadObject({required this.config, this.onUploadComplete});

  @override
  Future<bool> upload() async {
    /*
      This function uploads the contents contained in the config to the cloud.
      It returns true if the upload was successful.
    
   */

    AWSSigV4Signer client = AWSSigV4Signer(
        region: config.credentailsConfig.region,
        accessKey: config.credentailsConfig.accessKey,
        secretKey: config.credentailsConfig.secretKey,
        hostEndpoint: config.credentailsConfig.host);

    final datetime = Utils.generateDatetime(); //The current date

    final authorizationHeader = client.buildAuthorizationHeader(
      'PUT',
      '/${config.url}',
      {},
      Utils.trimString(datetime),
      requestPayload: config.content!,
    );

    var header = client.headers;
    header['Authorization'] = authorizationHeader;

    BaseOptions options = BaseOptions(method: 'PUT', headers: header);

    final dio = Dio(options);

    final Completer<bool> uploadCompleter = Completer();

    //Upload the object
    await dio.put(
      'https://${config.credentailsConfig.host}/${config.url}',
      data: config.content,
      onSendProgress: (count, total) {
        print('$count/$total');
        _uploadProgress.add([count, total]);
      },
    ).then(
      (value) {
        onUploadComplete?.call(value, value.headers['x-amz-version-id']![0]);
        uploadCompleter.complete(true);
      },
      onError: (error) {
        uploadCompleter.complete(false);
      },
    );

    return uploadCompleter.future;
  }

  @override
  void dispose() {
    _uploadProgress.close();
  }
}
