import 'dart:isolate';

import '../upload_utils/create_chunk_size_config.dart';

///[IsolateMessage] contains the needed variables for the isolate spawned when creating the file chunks for this file
class IsolateMessage {
  //This class would house the isolate send port and the create chunk config to be used to
  //Split the file into chunks

  SendPort
      sendPort; // The sendport to send data to the isolate that has een spawned

  ///[CreateChunkSizesIndexesConfig] contains information that determines how the chunks should be calculated
  CreateChunkSizesIndexesConfig config;

  IsolateMessage(this.config, this.sendPort);
}
