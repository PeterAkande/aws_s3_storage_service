A simple Package to handle Uploads, Multipart Uploads and Downloads in Dart
and Flutter apps.

``dart
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:aws_storage_service/src/aws_storage_service.dart';

AwsCredentialsConfig credentialsConfig = AwsCredentialsConfig(
  accessKey: 'YOURACCESSKEY', // This is a test accessKey, It is invallid here
  bucketName: 'testbucket', // The bucket name
  region: 'us-west-2', // The region of your Aws bucket allocation
  secretKey: 'YOURAWSSECRETKEY', // Your secret Key
);

testFunctions() async {
  await testFileUpload(); // This tests the file upload

  await testMultipartUpload(); // Test mulltipart upload

  await testResumeMultipartUpload(); //  Test resuming multipart upload

  await testDownload(); // Test download

  await testResumeDownload(); // Test resume download
}

Future testResumeDownload() async {
  //This tests uploading of a file
  String filePath = p.join(Directory.current.path, 'test_download.mp4');

  String fileUrl = 'file/ftest.mp4'; // The Url of the file in the bucket

  //Create a download config...
  //The download config contains all the configurations needed by the downloader to download the file
  DownloadFileConfig config = DownloadFileConfig(
    credentailsConfig: credentialsConfig,
    url: fileUrl,
    resumeDownload:
        true, // Set resume download to true if download is to be resumed
    downloadPath: filePath, // The file path of the file to be resumed
  );

  DownloadFile downloadFile = DownloadFile(
    config: config,
    onRecieveProgress: ((totalDownloaded, totalSize) =>
        print('Upload Status Callback ===> $totalDownloaded/$totalSize')),
    errorCallback: (errorMessage) => print('An error occurred $errorMessage'),
  ); // Create  a download file instance

  bool prepSuccessful =
      await downloadFile.prepareDownload(); // Prepate the download
  print('The download was prepared Successfully $prepSuccessful');

  downloadFile.downloadProgress.listen((event) {
    //You can listen to the download progress
    print('Upload Status Stream ===> ${event[0]}/${event[1]}');
  });

  if (prepSuccessful) {
    await downloadFile.download().then((value) {
      downloadFile.dispose();
    });
  }
}

Future testDownload() async {
  //Initiate a new upload
  String filePath = p.join(Directory.current.path, 'test_download.mp4');

  String fileUrl = 'file/ftest.mp4'; //The file URl in the bucket

  DownloadFileConfig config = DownloadFileConfig(
    credentailsConfig: credentialsConfig,
    url: fileUrl,
    downloadPath: filePath,
  );

  DownloadFile downloadFile = DownloadFile(
    config: config,
    onRecieveProgress: ((totalDownloaded, totalSize) =>
        print('Upload Status Callback ===> $totalDownloaded/$totalSize')),
    errorCallback: (errorMessage) => print('An error occurred $errorMessage'),
  );

  bool prepSuccessful = await downloadFile.prepareDownload();
  print('The download was prepared Successfully $prepSuccessful');

  downloadFile.downloadProgress.listen((event) {
    print('Upload Status Stream ===> ${event[0]}/${event[1]}');
  });

  if (prepSuccessful) {
    await downloadFile.download().then((value) {
      downloadFile.dispose();
    });
  }
}

Future testResumeMultipartUpload() async {
  String imageName = 'test.mp4'; //tHE Name of the file to be uploaded
  File file = File(p.join(Directory.current.path, 'test_files', imageName));

  //EtagLists is a list of the etags that have been uploaded.
  //For every chunk uploaded to aws, an Etag id is returned.
  //The package has a method that returns all the uploaded etag lists everytime a chunk upload was successful
  final eTagLists = [
    [2, "1ee28a7ac06786aff26d47298674c847"],
    [1, "18cc73a82389202aa085ee5751666726"],
    [4, "bf41ee73393dbfa1a5327fbb50aff054"],
    [5, "2848ec759573e3c5f6cadf1145e9efd9"]
  ];

  //The version id of the upload id is the unique id given to this upload when the upload was started
  final versionIdOrUploadId =
      'Zm9F2QhTuSZQHhnw1O8sThNk9fZ71lAUf20oTUQ11NrUaQy5DUwZ8oZ7fXuxCZywyY8mwUqsa54M3yg1S2QFIWGV.kv_QiMAxGlNHC55OAzBlDIusdJJ2jLF7qaQk9yg';

  //Create the config object.
  MultipartUploadConfig config = MultipartUploadConfig(
    credentailsConfig: credentialsConfig,
    file: file,
    url: 'file/f$imageName',
    resumeMultipart: true,
    versionId: versionIdOrUploadId,
    etagsLists: eTagLists,
  );

  MultipartFileUpload multipartFileUpload = MultipartFileUpload(
    config: config,

    onError: (error, list, s) {
      print('An error occurred $error');
    },

    //The function onVersionIdCreated is called when the version id is just created.
    //Since the version is always just created for a new multipart upload, It is basically only
    //Needed when a new Multipart upload is done.
    //The version id is a parameter. The version id can be cached for further use.
    //The ball is in your court to do anything with the version id.
    onVersionIdCreated: (versionId) => print('version id created $versionId'),

    //Th e
    onPartUploadComplete: (etagList, versionId) => print(
        'Part upload completed ---> etagList is $etagList and versionId is $versionId'),
    onUploadComplete: (etagList, versionId) => print(
        'Part upload completed ---> etagList is $etagList and versionId is $versionId'),
  );

  multipartFileUpload.uploadCompletedState.listen((event) {
    //Event is a boolean. This is true when the file upload is done
    print('Upload State $event');
  });

  multipartFileUpload.uploadProgress.listen((event) {
    print('Upload progress \n${event[0]} / ${event[1]}');
  });

  bool preparingSuccessful =
      await multipartFileUpload.prepareMultipartRequest();

  if (preparingSuccessful) {
    await multipartFileUpload.upload();
  }
}

Future testMultipartUpload() async {
  String imageName = 'test.mp4';
  File file = File(p.join(Directory.current.path, 'test_files', imageName));

  MultipartUploadConfig config = MultipartUploadConfig(
    file: file,
    url: 'file/f$imageName',
    credentailsConfig: credentialsConfig,
  );

  MultipartFileUpload multipartFileUpload = MultipartFileUpload(
    config: config,
    onError: (error, list, s) {
      print('An error occurred $error');
    },

    //The function onVersionIdCreated is called when the version id is just created.
    //Since the version is always just created for a new multipart upload, It is basically only
    //Needed when a new Multipart upload is done.
    //The version id is a parameter. The version id can be cached for further use.
    //The ball is in your court to do anything with the version id.
    onVersionIdCreated: (versionId) => print('version id created $versionId'),

    //Th e
    onPartUploadComplete: (etagList, versionId) => print(
        'Part upload completed ---> etagList is $etagList and versionId is $versionId'),
    onUploadComplete: (etagList, versionId) => print(
        'Part upload completed ---> etagList is $etagList and versionId is $versionId'),
  );

  multipartFileUpload.uploadCompletedState.listen((event) {
    //Event is a boolean. This is true when the file upload is done
    print('Upload State $event');
  });

  multipartFileUpload.uploadProgress.listen((event) {
    print('Upload progress \n${event[0]} / ${event[1]}');
  });

  bool preparingSuccessful =
      await multipartFileUpload.prepareMultipartRequest();

  if (preparingSuccessful) {
    await multipartFileUpload.upload();
  }
}

Future testFileUpload() async {
  File file = File(p.join(Directory.current.path, 'web.pdf'));

  print(file.lengthSync());

  UploadTaskConfig config = UploadTaskConfig(
      credentailsConfig: credentialsConfig,
      url: 'file/web23.pdf',
      uploadType: UploadType.file,
      file: file);

  UploadFile uploadFile = UploadFile(config: config);

  uploadFile.uploadProgress.listen((event) {
    print('${event[0]}/ ${event[1]}');
  });

  await uploadFile.upload().then((value) {
    print(value);
    uploadFile.dispose();
  });
}

Future testUploadObject() async {
  String url = r'testfile.text';

  UploadTaskConfig config = UploadTaskConfig(
      credentailsConfig: credentialsConfig,
      url: url,
      uploadType: UploadType.stringObject,
      content: 'Welcome to Amazon S3. agaian ana diwofofw ans');

  final UploadObject uploadObject = UploadObject(config: config);

  await uploadObject.upload();
}


```
