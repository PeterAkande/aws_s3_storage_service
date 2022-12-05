import 'package:aws_storage_service/aws_storage_service.dart';
import 'package:test/test.dart';

AwsCredentialsConfig credentialsConfig = AwsCredentialsConfig(
    accessKey: '', bucketName: '', region: '', secretKey: '');

void main() {
  group(
    'An exception is given if not all required parameters are given for different upload operations',
    () {
      test(
        'An error is thrown when a fileType is UploadType.file and filePath is null',
        () {
          expect(
              () => UploadTaskConfig(
                  credentailsConfig: credentialsConfig,
                  url: 'url',
                  uploadType: UploadType.file),
              throwsA(isA<AssertionError>()));
        },
      );
      test(
        'An error is thrown when a fileType is UploadType.stringObject and content is null',
        () {
          expect(
              () => UploadTaskConfig(
                  url: 'url',
                  credentailsConfig: credentialsConfig,
                  uploadType: UploadType.stringObject),
              throwsA(isA<AssertionError>()));
        },
      );
    },
  );
}
