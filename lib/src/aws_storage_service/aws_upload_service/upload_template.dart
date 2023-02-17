abstract class UploadTask {
  Future<bool> upload();

  Stream<List<int>> get uploadProgress;

  void dispose();
}
