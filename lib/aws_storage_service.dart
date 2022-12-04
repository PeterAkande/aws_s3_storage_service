import 'dart:io';

import 'package:aws_storage_service/src/aws_storage_service/aws_download_service/download_file_service.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_download_service/download_file_utils/download_file_config.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/multipart_upload/multipart_file_upload.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_file.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_utils/multipart_upload_config.dart';
import 'package:path/path.dart' as p;

import 'package:aws_storage_service/src/aws_storage_service.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_object.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_utils/upload_object_config.dart';

int calculate() {
  return 6 * 7;
}

testFunctions() async {
  print(Directory.current);

  // await testFileUpload();
  // await testMultipartUpload();

  // await testResumeMultipartUpload();

  // await testDownload();

  await testResumeDownload();
}

Future testResumeDownload() async {
  String filePath = p.join(Directory.current.path, 'test_download.mp4');

  String fileUrl = 'file/ftest.mp4';

  DownloadFileConfig config = DownloadFileConfig(
    url: fileUrl,
    resumeDownload: true,
    downloadPath: filePath,
  );

  DownloadFile downloadFile = DownloadFile(
    config: config,
    onRecieveProgress: ((totalDownloaded, totalSize) =>
        print('Upload Status Callback ===> $totalDownloaded/$totalSize')),
    errorCallback: (errorMessage) => print('An error occurred $errorMessage'),
  );

  bool prepSuccessful = await downloadFile.prepareDownload();
  print(prepSuccessful);

  downloadFile.downloadProgress.listen((event) {
    print('Upload Status Stream ===> ${event[0]}/${event[1]}');
  });

  if (prepSuccessful) {
    await downloadFile.download().then((value) {
      downloadFile.dispose();
    });
  }
}

Future testDownload() async {
  String filePath = p.join(Directory.current.path, 'test_download.mp4');

  String fileUrl = 'file/ftest.mp4';

  DownloadFileConfig config = DownloadFileConfig(
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
  print(prepSuccessful);

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
  String imageName = 'test.mp4';
  File file = File(p.join(Directory.current.path, 'test_files', imageName));

  //Create the config object.
  MultipartUploadConfig config = MultipartUploadConfig(
    file: file,
    url: 'file/f$imageName',
    host: host,
    resumeMultipart: true,
    versionId:
        'Zm9F2QhTuSZQHhnw1O8sThNk9fZ71lAUf20oTUQ11NrUaQy5DUwZ8oZ7fXuxCZywyY8mwUqsa54M3yg1S2QFIWGV.kv_QiMAxGlNHC55OAzBlDIusdJJ2jLF7qaQk9yg',
    etagsLists: [
      [2, "1ee28a7ac06786aff26d47298674c847"],
      [1, "18cc73a82389202aa085ee5751666726"],
      [4, "bf41ee73393dbfa1a5327fbb50aff054"],
      [5, "2848ec759573e3c5f6cadf1145e9efd9"]
    ],
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

  MultipartUploadConfig config =
      MultipartUploadConfig(file: file, url: 'file/f$imageName', host: host);

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
      url: 'file/web3.pdf',
      host: host,
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
      url: url,
      host: host,
      uploadType: UploadType.stringObject,
      content: 'Welcome to Amazon S3. agaian ana diwofofw ans');

  final UploadObject uploadObject = UploadObject(config: config);

  await uploadObject.upload();
}
