import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:aws_storage_service/src/aws_signer/aws_sigv4_signer.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_utils/create_chunk_size_config.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_utils/multipart_upload_config.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../../aws_signer/utils.dart';
import '../../../aws_storage_service.dart';
import 'isolate_message_config.dart';

class MultipartFileUploadController {
  //This class would contain the various details about a multipart upload like the chunk indexes,
  //The uploaded file chunks, The length of the file,

  // This file chunk index is a list of multple lists of three elements lists and a list of two elements.
  // For example [[1, 2, 3], [2, 3, 4], [2, 6]]
  //The list with two items signifies the last chunk to be uploaded.

  //The first item in the list is the partNumber
  //The second item in the list is the Chunk start index
  //The third item in the list os the chunk end index

  //For the list with two items,
  //The first item is the partNumber and the last item in the list is the Chink start index.
  //There is no need for a last index chunk since the last chunk is from the start index to the end of the file
  late final List<List<int>> _fileChunksIndexes;

  //This is the signer for all the requests that would be made to the AWS S3 service
  late final AWSSigV4Signer signer;

  //This cancel token would be used to cancel all requests if the pause upload function is called.
  CancelToken _cancelToken = CancelToken();

  CancelToken get cancelToken => _cancelToken;

  //The length of the file in bytes.. or more understandable, the file size in bytes
  late final int fileLength;

  //This is the length of each file chunk to be uploaded in the multipart request
  late final int chunkSize;

  //The number of parts is the number of chunks being uploaded to the cloud
  late final int _numberOfParts;

  int get numberOfParts => _numberOfParts; //Expose a getter only

  //This would be set through the function
  late final MultipartUploadConfig _config;

  set config(MultipartUploadConfig config) {
    _config = config;
    signer = AWSSigV4Signer(
        region: config.credentailsConfig.region,
        accessKey: _config.credentailsConfig.accessKey,
        hostEndpoint: _config.credentailsConfig.host,
        secretKey: _config.credentailsConfig.secretKey);
  }

  MultipartUploadConfig get config => _config;

  //This list would hold the list of uploaded Etags.
  //The etag is a List [partNUmber, versionId]
  final List<List<dynamic>> etagsLists = [];

  bool _uploadPaused = false;

  //This gets the status of the upload.
  bool get uploadPaused => _uploadPaused;

  set uploadPaused(bool status) {
    //Set the uploadPaused value to the status and call the pauseUpload Function here.
    _uploadPaused = true;
  }

  //This variable pathsThatHaveBeenUploaded is only used for resume Multipart uploads
  //It is a list containing the parts that have been uploaded.
  //The chunk indexes with matching part numbers are not included when the file chunk indexes is
  //Being calculated.

  final List<int> alreadyUploadedParts = [];

  getPartsThatHaveBeenUploaded() {
    //This gets the parts that have been uploaded from the Etag lists supplied.

    for (var eTagList in etagsLists) {
      //Each etag list is of form [partNumber, versionId]
      alreadyUploadedParts.add(eTagList[0]);
    }
  }

  // List<List<dynamic>> get eTagLists => _etagsLists;

  void addEtag(List newEtag) {
    etagsLists.add(newEtag);
  }

  void addAllEtagLists(List<List<dynamic>> eTags) {
    etagsLists.addAll(eTags);
  }

  // MultipartFileUploadController({required this.config});

  Future<List<int>> getChunk(File file, {required int start, int? end}) async {
    //This function would be incharge of getting certain chunks from a file
    //It returns the bytes of the file starting from position 'start' to 'end'

    final Completer<List<int>> bytePayloadGottenCompleter = Completer();

    List<int> bytePayload = [];

    file.openRead(start, end).listen(
      (bytes) {
        bytePayload.addAll(bytes);
      },
      onDone: () {
        bytePayloadGottenCompleter.complete(bytePayload);
      },
    );

    return bytePayloadGottenCompleter
        .future; //Just some dummy data to get rid of errors
  }

  void addFileChunkIndex(List<int> fileChunk) {
    //This function is used to add a file chunk to the file chunk index.
    //It is called when an upload fails.

    //Since each file chunk is removed from the file chunk index when ever an upload os started,
    //It is logical for the file chunk to be added back to the file chunk index so that it can be picked up and
    //reuploaded.

    _fileChunksIndexes.add(fileChunk);
  }

  List<int> getFileChunkIndex() {
    //This would pop and an return a random file chunk index

    if (_fileChunksIndexes.isEmpty) return [];

    return _fileChunksIndexes.removeAt(0);
  }

  Future<String> createMultipartUploadRequest() async {
// final uri = Uri.parse('https://$host$uriOfFile?uploads');

    // This function would be used to initiate a multipart request.
    // In the aws

    final dateTime = Utils.generateDatetime();

    final uri =
        Uri.https(config.credentailsConfig.host, config.url, {'uploads': ''});
    final authHeader = signer.buildAuthorizationHeader(
      'POST',
      '/${config.url}',
      {'uploads': ''},
      dateTime,
    );

    var headers = signer.headers;
    headers['Authorization'] = authHeader;

    try {
      var response = await http.post(uri, headers: headers);
      if (response.statusCode == 200) {
        var xmlObj = XmlDocument.parse(response.body);

        String versionId = xmlObj.findAllElements('UploadId').single.text;
        return Future.value(versionId);
      } else {
        return Future.error('Error Creating Multipart Request');
      }
    } on SocketException {
      return Future.error(
          'An error Occured. Please check Internet connectivity');
    }
  }

  Future<bool> completeMultipartRequest(
      {Function(List<List<dynamic>> etagList, String versionId)?
          onUploadComplete}) async {
    //This would complete the multipat request.
    //It would return true if it was successful

    Set<String> etagStrings = {};
    // etagsLists = etagsLists.toSet().toList(); //Remove any duplicates
    etagsLists.retainWhere((element) => etagStrings.add(element[1]));
    etagsLists.sort(((a, b) => a[0].compareTo(b[0]))); //Sort the etagList

    var basicRequestTemplateBuffer =
        StringBuffer(); //A string buffer is used to better manage memory issues

    String dateTime = Utils.generateDatetime();

    final Completer<bool> requestCompletedSuccessfully = Completer();

    basicRequestTemplateBuffer.write(
        '''<CompleteMultipartUpload xmlns="http://s3.amazonaws.com/doc/2006-03-01/">''');

    for (List etag in etagsLists) {
      basicRequestTemplateBuffer.write('''<Part>
      <ETag>${etag[1]}</ETag>
      <PartNumber>${etag[0]}</PartNumber>
   </Part>''');
    }

    basicRequestTemplateBuffer.write('</CompleteMultipartUpload>');

    String authHeader = signer.buildAuthorizationHeader(
        'POST', '/${config.url}', {'uploadId': config.versionId}, dateTime,
        requestPayload: basicRequestTemplateBuffer.toString(),
        unSignedPayload: true);

    final uri = Uri.https(config.credentailsConfig.host, config.url,
        {'uploadId': config.versionId});

    var headers = signer.headers;
    headers['Authorization'] = authHeader;
    try {
      var response = await http.post(uri,
          headers: headers, body: basicRequestTemplateBuffer.toString());

      if (response.statusCode == 200) {
        // print(
        //   response.headers['x-amz-version-id'] as String,
        // );
        onUploadComplete?.call(
          etagsLists,
          response.headers['x-amz-version-id'] as String,
        );

        requestCompletedSuccessfully.complete(true);
      } else {
        // print(response.statusCode);
        // print(response.body);
        // print(response.reasonPhrase);
        requestCompletedSuccessfully.complete(false);
      }
    } catch (e) {
      requestCompletedSuccessfully.complete(false);
    }

    return requestCompletedSuccessfully.future;
  }

  pauseUploads() {
    //This would pause all uploads.
    _cancelToken.cancel();

    _cancelToken = CancelToken(); // reassign the Token
  }

  Future createFileChunkIndexes() async {
    //This function creates a list of the starting and ending indexes of the bytes of the data to be read at a time depending on tjhe defined chunk size
    final int numberOfChunks = fileLength ~/ chunkSize;

    CreateChunkSizesIndexesConfig createChunkSizesIndexesConfig =
        CreateChunkSizesIndexesConfig(
      numberOfChunks: numberOfChunks,
      chunkSize: chunkSize,
      alreadyUploadParts: alreadyUploadedParts,
    );

    //TODO: Use the compute function in a flutter app.

    // await compute(createChunkIndexes, createChunkSizesIndexesParameterModel)
    //     .then((value) {
    //   fileChunksIndexes.addAll(value.); // Add all to the file chunkIndexes
    // });

    final receivePort = ReceivePort();

    IsolateMessage isolateMessage =
        IsolateMessage(createChunkSizesIndexesConfig, receivePort.sendPort);

    await Isolate.spawn(createChunkIndexes, isolateMessage);

    _fileChunksIndexes = await receivePort.first as List<List<int>>;

    _numberOfParts = _fileChunksIndexes.length;

    return _fileChunksIndexes; //Return the file chunk indexes since this would be run in an isolate
  }

  setChunkSize() {
    //This function is used to set the chunk size. The chunk size is dependent on the size
    //Of the file. For larger files, the chunk size is larger

    int threshHold100 = 100 * 1024 * 1024; //This is 100mb
    int threshHold75 = 75 * 1024 * 1024; //This is 75mb
    // int threshHold100 = 100 * 1000 * 1000; //This is 75mb

    if (fileLength < threshHold75) {
      //The file length is smaller than 75 mb.
      chunkSize = 5 * 1024 * 1024; //Chunk size is 5mb
    } else if (fileLength > threshHold75 && fileLength < threshHold100) {
      // The file length is between 75 mb and 100mb
      chunkSize = 12 * 1024 * 1024; //Chunk size is 12 mb
    } else {
      //Greater then 100 mb

      chunkSize = 18 * 1024 * 1024; //Chunk size is 18mb
    }
  }
}

Future<void> createChunkIndexes(IsolateMessage message) {
  //This would be run in an isolate because for larger files,
  // this for loop seems to block the main UI thread (For flutter apps)

  //So.. what is being done here is that the file chunk positions are being calculated.
  //More details about the file chunk indexes is in the definition.

  final List<List<int>> fileChunksIndexes = [];
  for (int i = 0; i < message.config.numberOfChunks + 1; i++) {
    if (message.config.alreadyUploadParts.contains(i + 1)) {
      //The part has been uploaded before. Skip to the next one
      continue;
    }

    if (i == message.config.numberOfChunks) {
      //This is the last chunk to be uploaded.
      fileChunksIndexes.add([i + 1, message.config.chunkSize * i]);
    } else {
      fileChunksIndexes.add([
        i + 1,
        message.config.chunkSize * i,
        message.config.chunkSize * i + message.config.chunkSize
      ]);
    }
  }

  Isolate.exit(message.sendPort, fileChunksIndexes);
}
