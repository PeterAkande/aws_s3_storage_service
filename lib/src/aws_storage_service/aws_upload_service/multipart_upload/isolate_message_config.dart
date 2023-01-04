import 'dart:isolate';

import '../upload_utils/create_chunk_size_config.dart';

class IsolateMessage {
  //This class would house the isolate send port and the create chunk config to be used to
  //Split the file into chunks

  SendPort sendPort;
  CreateChunkSizesIndexesConfig config;

  IsolateMessage(this.config, this.sendPort);
}
