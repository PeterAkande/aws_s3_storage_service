import 'dart:io';

class MultipartUploadConfig {
  //This would contain the configurations for the multipart uploads.

  String url; //The uri of the file in the bucket

  String host;

  File file; //The file instance.
  bool resumeMultipart =
      false; //This should  be true if the multipart file is being resumed.

  //This would contain the parts of the multipart uploads that have been completed
  //If it is empty, the file does not have any of its parts uploaded.
  List<List<dynamic>> etagsLists;

  //This is the version id of the file that is to be uploaded. It would be empty for a new request.
  //It should not be empty for a resuming multipart request.
  String versionId;

  MultipartUploadConfig({
    required this.file,
    required this.url,
    required this.host,
    this.versionId = '',
    this.etagsLists = const [],
    this.resumeMultipart = false,
  }) {
    if (resumeMultipart) assert(versionId.isNotEmpty);
  }
}
