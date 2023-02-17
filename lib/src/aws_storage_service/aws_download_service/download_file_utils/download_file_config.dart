import 'package:aws_storage_service/aws_storage_service.dart';

///Configuration for all download actions or Process
class DownloadFileConfig {
  ///The path of the file in the bucket.
  final String url;

  //The path the file should be downloaded in on the device.
  final String downloadPath;

  ///The specific version id to be downloaded.
  final String versionId;

  ///This specifies if the download should be resumed
  bool resumeDownload;

  ///The credentials for the Aws client.It is of type [AwsCredentialsConfig]
  AwsCredentialsConfig credentailsConfig;

  final bool continueDownloadIfFileDoesNotExist;

  DownloadFileConfig(
      {required this.url,
      required this.downloadPath,
      required this.credentailsConfig,
      this.versionId = '',
      this.continueDownloadIfFileDoesNotExist = true,
      this.resumeDownload = false});
}
