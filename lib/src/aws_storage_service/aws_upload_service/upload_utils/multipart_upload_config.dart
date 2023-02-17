import 'dart:io';

import '../../../../aws_storage_service.dart';

///[MultipartUploadConfig] defines the information that woulld be used to upload the file
class MultipartUploadConfig {
  //This would contain the configurations for the multipart uploads.

  ///The url of the file in the bucket
  String url; //The uri of the file in the bucket

  ///The file to be uploaded. Instance of [File]
  File file; //The file instance.
  bool resumeMultipart =
      false; //This should  be true if the multipart file is being resumed.

  ///This would contain the parts of the multipart uploads that have been completed
  ///If it is empty, the file does not have any of its parts uploaded.
  List<List<dynamic>> etagsLists;

  //This is the version id of the file that is to be uploaded. It would be empty for a new request.
  //It should not be empty for a resuming multipart request.
  String versionId;
  AwsCredentialsConfig credentailsConfig;

  MultipartUploadConfig({
    required this.file,
    required this.url,
    required this.credentailsConfig,
    this.versionId = '',
    this.etagsLists = const [],
    this.resumeMultipart = false,
  }) {
    if (resumeMultipart) assert(versionId.isNotEmpty);
  }
}
