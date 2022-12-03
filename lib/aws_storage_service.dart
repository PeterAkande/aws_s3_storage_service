import 'dart:io';

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
  await testMultipartUpload();
}

Future testMultipartUpload() async {
  String imageName = 'img_1.jpg';
  File file = File(p.join(Directory.current.path, imageName));

  MultipartUploadConfig config =
      MultipartUploadConfig(file: file, url: 'file/f$imageName', host: host);

  MultipartFileUpload multipartFileUpload = MultipartFileUpload(
    config: config,
    onError: (error, list, s) {
      print('An error occurred $error');
    },
    onVersionIdCreated: (versionId) => print('version id created $versionId'),
    onPartUploadComplete: (etagList, versionId) => print(
        'Part upload completed ---> etagList is $etagList and versionId is $versionId'),
    onUploadComplete: (etagList, versionId) => print(
        'Part upload completed ---> etagList is $etagList and versionId is $versionId'),
  );

  multipartFileUpload.uploadCompletedState.listen((event) {
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
      url: 'file/test_1_file.pdf',
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
