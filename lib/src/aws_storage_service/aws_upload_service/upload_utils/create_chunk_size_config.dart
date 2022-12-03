class CreateChunkSizesIndexesConfig {
  //This would contain the variables needed for calculating chunks.

  int numberOfChunks;
  int chunkSize;

  CreateChunkSizesIndexesConfig(
      {required this.numberOfChunks, required this.chunkSize});
}
