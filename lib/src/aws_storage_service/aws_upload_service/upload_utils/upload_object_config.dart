import 'dart:io';

import '../../../../aws_storage_service.dart';

class UploadTaskConfig {
  String url;
  String? content;
  File? file;
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

  /*
   : assert(uploadType != UploadType.file && filePath == null,
            'Do not pass filePath if upload type is not of file or multipart file'),
        assert(uploadType == UploadType.stringObject && content != null)
  */
}

enum UploadType { multipartFIle, stringObject, file }
