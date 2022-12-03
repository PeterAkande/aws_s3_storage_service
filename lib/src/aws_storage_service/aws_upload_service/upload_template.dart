abstract class UploadTask {
  //This would form the skeleton of the upload tasks
  Future<bool> upload();

  Stream<List<int>> get uploadProgress;

  void dispose();
}
