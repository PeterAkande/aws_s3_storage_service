import 'package:aws_storage_service/aws_storage_service.dart'
    as aws_storage_service;

void main(List<String> arguments) async {
  print('Hello world: ${aws_storage_service.calculate()}!');

  await aws_storage_service.testFunctions();
}
