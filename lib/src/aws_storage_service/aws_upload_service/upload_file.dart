import 'dart:io';

import 'package:aws_storage_service/src/aws_signer/aws_sigv4_signer.dart';
import 'package:aws_storage_service/src/aws_signer/utils.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_template.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_utils/upload_function.dart';
import 'package:rxdart/rxdart.dart';

import 'upload_utils/upload_object_config.dart';

///[UploadFile] handles the uploading of a [File] of less than 5mb. Greater than 5mb should use [MultipartFileUpload]
class UploadFile extends UploadTask {
  final UploadTaskConfig config;

  ///[_uploadProgress] exposes a stream that gives the upload progress for the file being uploaded
  ///
  ///[BehaviourSubject] is used so that the latest value broadcasted to any new subscriber
  final BehaviorSubject<List<int>> _uploadProgress =
      BehaviorSubject.seeded([0, 0]);

  ///[uploadProgess] exposes a stream that gives the upload progress for the file being uploaded
  @override
  Stream<List<int>> get uploadProgress => _uploadProgress.asBroadcastStream();

  ///[onSendComplete] is called when the file has been uploaded completely
  final Function(dynamic response, String versionId)? onSendComplete;

  UploadFile({required this.config, this.onSendComplete})
      : assert(config.file != null,
            'Please assign the value of file in the UploadTask Config'),
        assert(config.uploadType == UploadType.file,
            'Please set the upload file Type to UploadType.file');

  @override
  Future<bool> upload() async {
    //Upload the file to the cloud.
    //The file path is contained in the UploadTask config.

    AWSSigV4Signer client = AWSSigV4Signer(
        region: config.credentailsConfig.region,
        accessKey: config.credentailsConfig.accessKey,
        secretKey: config.credentailsConfig.secretKey,
        hostEndpoint: config.credentailsConfig.host);

    File file = config.file!;

    List<int> fileByte = await file.readAsBytes();

    final datetime = Utils.generateDatetime();

    final authorizationHeader = client.buildAuthorizationHeader(
        'PUT', '/${config.url}', {}, Utils.trimString(datetime),
        unSignedPayload: true, bytesPayload: fileByte);

    var header = client.headers;
    header['Authorization'] = authorizationHeader;

    //Now upload the file
    final bool uploadSuccessful = await fileUploader(
        onSendProgress: (count, total) {
          _uploadProgress.add([count, total]);
        },
        bytesPayload: fileByte,
        onSendComplete: onSendComplete,
        headers: header,
        url: 'https://${config.credentailsConfig.host}/${config.url}');

    return uploadSuccessful;
  }

  @override
  void dispose() {
    _uploadProgress.close();
  }
}
