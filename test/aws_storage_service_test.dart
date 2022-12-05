import 'package:aws_storage_service/aws_storage_service.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_file.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_utils/upload_object_config.dart';
import 'package:test/test.dart';

void main() {
  group(
    'An exception is given if not all required parameters are given for different upload operations',
    () {
      test(
        'An error is thrown when a fileType is UploadType.file and filePath is null',
        () {
          expect(
              () => UploadTaskConfig(
                  url: 'url', host: 'host', uploadType: UploadType.file),
              throwsA(isA<AssertionError>()));
        },
      );
      test(
        'An error is thrown when a fileType is UploadType.stringObject and content is null',
        () {
          expect(
              () => UploadTaskConfig(
                  url: 'url',
                  host: 'host',
                  uploadType: UploadType.stringObject),
              throwsA(isA<AssertionError>()));
        },
      );
    },
  );
}
