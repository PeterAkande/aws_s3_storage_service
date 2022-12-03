import 'dart:io';

class UploadTaskConfig {
  String url;
  String host;
  String? content;
  File? file;
  final UploadType uploadType;

  UploadTaskConfig({
    required this.url,
    required this.host,
    required this.uploadType,
    this.content,
    this.file,
  });

  /*
   : assert(uploadType != UploadType.file && filePath == null,
            'Do not pass filePath if upload type is not of file or multipart file'),
        assert(uploadType == UploadType.stringObject && content != null)
  */
}

enum UploadType { multipartFIle, stringObject, file }
