import 'dart:io';

import 'package:aws_storage_service/src/aws_signer/aws_sigv4_signer.dart';
import 'package:aws_storage_service/src/aws_signer/utils.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_template.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_utils/upload_function.dart';
import 'package:rxdart/rxdart.dart';

import 'upload_utils/upload_object_config.dart';

class UploadFile extends UploadTask {
  ///This class is for files that are lesser than 6 mb
  ///If the upload is successful, true is returned
  ///
  final UploadTaskConfig config;

  //BehaviourSubject is used so that the latest value broadcasted to any new subscriber
  final BehaviorSubject<List<int>> _uploadProgress =
      BehaviorSubject.seeded([0, 0]);

  @override
  Stream<List<int>> get uploadProgress => _uploadProgress.asBroadcastStream();

  UploadFile({required this.config})
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

    print(fileByte.length);

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
        headers: header,
        url: 'https://${config.credentailsConfig.host}/${config.url}');

    return uploadSuccessful;
  }

  @override
  void dispose() {
    _uploadProgress.close();
  }
}
