import 'dart:io';

import '../../../../aws_storage_service.dart';

///Defines the information to be used in the [UploadFile] and [UploadObject] processes
class UploadTaskConfig {
  String url;

  ///String of the content of the object to be uploaded. Only valid for [UploadObject]
  String? content;
  File? file;

  ///The [UploadType]
  final UploadType uploadType;
  AwsCredentialsConfig credentailsConfig;

  UploadTaskConfig({
    required this.url,
    required this.uploadType,
    required this.credentailsConfig,
    this.content,
    this.file,
  }) {
    if (uploadType == UploadType.file ||
        uploadType == UploadType.multipartFIle) {
      assert(file != null);
    }

    if (uploadType == UploadType.stringObject) {
      assert(content != null);
    }
  }
}

///Defines the type of file bring uploaded
enum UploadType { multipartFIle, stringObject, file }
