class CreateChunkSizesIndexesConfig {
  //This would contain the variables needed for calculating chunks.

  final int numberOfChunks;
  final int chunkSize;
  final List<int> alreadyUploadParts;

  CreateChunkSizesIndexesConfig(
      {required this.numberOfChunks,
      required this.chunkSize,
      this.alreadyUploadParts = const []});
}
