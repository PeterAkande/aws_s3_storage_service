class DownloadFileConfig {
  //This would house the configurations for the download object

  final String url; //The path of the file in the bucket.

  final String downloadPath; //The path the file should be downloaded at.

  //The specific version id to be downloaded.
  //If it is needed to download a specific version.
  final String versionId;

  //This specifies whether a download process is being resumed.
  //It is false if a new download process is needed.
  final bool resumeDownload;

  DownloadFileConfig(
      {required this.url,
      required this.downloadPath,
      this.versionId = '',
      this.resumeDownload = false});
}
