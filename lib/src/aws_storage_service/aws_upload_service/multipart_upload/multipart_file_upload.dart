import 'dart:async';
import 'dart:developer';

import 'package:aws_storage_service/src/aws_storage_service.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/multipart_upload/uploading_counter.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_template.dart';
import 'package:aws_storage_service/src/aws_storage_service/aws_upload_service/upload_utils/multipart_upload_config.dart';
import 'package:rxdart/rxdart.dart';

import '../../../aws_signer/aws_sigv4_signer.dart';
import '../../../aws_signer/utils.dart';
import '../upload_utils/upload_function.dart';
import 'multipart_upload_controller.dart';

class MultipartFileUpload extends UploadTask {
  final UploadingNumberNotifier _uploadingNumberNotifier =
      UploadingNumberNotifier();

  final Function(List<List<dynamic>> etagList, String versionId)?
      onPartUploadComplete; //A function that would be called when each chunk is sent. The etagList and the version id is sent

  final Function(List<List<dynamic>> etagList, String versionId)?
      onUploadComplete; //A function that would be called when all upload is done

  //This is the function that would be called once the version id s created.
  //Other actions by the can be done, maybe caching the version id.
  final Function(String)? onVersionIdCreated;

  // a function that would be called when an error is encountered
  //It returns the error, the version id of the file and the etagList that has been uploaded sofar
  final Function(String error, String versionId, List<List<dynamic>> etagList)?
      onError;

  final MultipartFileUploadController _fileUploadController =
      MultipartFileUploadController();

  final MultipartUploadConfig config;

  final BehaviorSubject<List<int>> _uploadProgress =
      BehaviorSubject.seeded([0, 0]);

  //This would act as the stream to give the current state of the upload of the file.
  final BehaviorSubject<bool> _uploadCompletedUpdate =
      BehaviorSubject.seeded(false);

  final int numberOfParallelUploads;

  MultipartFileUpload({
    required this.config,
    this.onError,
    this.onUploadComplete,
    this.onVersionIdCreated,
    this.onPartUploadComplete,
    this.numberOfParallelUploads =
        2, //This is the default number of uploads to be done in parallel
  }) {
    _uploadingNumberNotifier.addListener(_shouldUpload, fireImmediately: false);
    _uploadingNumberNotifier.addListener(_calculateUploadProgress,
        fireImmediately: false);
    _fileUploadController.config = config;
  }

  int get numberOfUploadingRequests =>
      _uploadingNumberNotifier.numberOfActiveRequests;

  @override
  Stream<List<int>> get uploadProgress => _uploadProgress.asBroadcastStream();

  //This would return the update to the upload;
  Stream<bool> get uploadCompletedState =>
      _uploadCompletedUpdate.asBroadcastStream();

  Future<bool> prepareMultipartRequest() async {
    //This function prepares all that is needed for a multipart request.
    //Be it a resume multipart request or not.

    bool prepareOrCreateSuccess;

    if (config.resumeMultipart) {
      prepareOrCreateSuccess = await _resumeMultipartUpload();
    } else {
      prepareOrCreateSuccess = await _createMultipartUpload();
    }

    return prepareOrCreateSuccess;
  }

  Future _uploadPart() async {
    //What this function would do is take a chunk and upload it.
    //It is called automatically when a

    List<int> fileChunkIndex = _fileUploadController.getFileChunkIndex();

    if (_fileUploadController.uploadPaused) {
      //The upload has been paused.
      //DO not upload another another chunk.
      _uploadCompletedUpdate.add(false);

      return;
    }

    if (fileChunkIndex.isEmpty) {
      if (_uploadingNumberNotifier.numberOfActiveRequests != 0) return;
      //If the fileCHunkIndex is empty and there are no active requests,
      //It means that the upload is finished.

      //Therefore, complete the upload

      bool completeMulitpartSuccessful = await _fileUploadController
          .completeMultipartRequest(onUploadComplete: onUploadComplete);

      if (completeMulitpartSuccessful) {
        _uploadCompletedUpdate.add(true);
      } else {
        onError?.call('Error Completing Request', config.versionId,
            _fileUploadController.etagsLists);
        _uploadCompletedUpdate.add(false);
      }

      dispose();
      return;
    }

    //Get the file chunk from the controller
    List<int> fileChunk = await _fileUploadController.getChunk(
      config.file,
      start: fileChunkIndex[1],
      end: fileChunkIndex.length == 2 ? null : fileChunkIndex[2],
    );

    _uploadingNumberNotifier.oneUploadAdded();

    await _upload(fileChunk, fileChunkIndex[0]).then((uploadCompleted) {
      if (!uploadCompleted) {
        //The upload was not completed.
        //Since the upload was not completed, add the file chunk index back to the file chunk index.

        _fileUploadController.addFileChunkIndex(fileChunkIndex);
        onError?.call(
            'Error uploading file chunk of part number ${fileChunkIndex[0]}',
            _fileUploadController.config.versionId,
            _fileUploadController.etagsLists);
      }
      _uploadingNumberNotifier.oneUploadDone();
    });
  }

  Future pauseUpload() async {
    ///This function would be used to pause an upload.
    ///Basically, all the requests are stopped.
    ///The error callback is triggered after the pauseUpload is called.

    _fileUploadController.uploadPaused = true;
  }

  _calculateUploadProgress(int _) {
    //This function would be incharge of calculating the upload progress.
    //When a new request is started, the upload progress is recalculated and added to the stream.

    int totalChunks = _fileUploadController.numberOfParts;
    int uploadedChunks = _fileUploadController.etagsLists.length;

    int numberOfBytesUploaded =
        uploadedChunks ~/ totalChunks * _fileUploadController.fileLength;

    _uploadProgress
        .add([numberOfBytesUploaded, _fileUploadController.fileLength]);
  }

  Future<bool> _upload(List<int> fileByte, int partNumber) async {
    // This would upload a chunk to the cloud.

    //Upload the chunk to the cloud.

    AWSSigV4Signer signer = AWSSigV4Signer(
        region: config.credentailsConfig.region,
        accessKey: config.credentailsConfig.accessKey,
        secretKey: config.credentailsConfig.secretKey,
        hostEndpoint: config.credentailsConfig.host);

    final datetime = Utils.generateDatetime();

    Map<String, String> queryParams = {
      'uploadId': config.versionId,
      'partNumber': partNumber.toString()
    };

    String authHeader = signer.buildAuthorizationHeader(
        'PUT', '/${config.url}', queryParams, datetime,
        bytesPayload: fileByte, unSignedPayload: true);

    Map<String, String> headers = signer.headers;
    headers['Authorization'] = authHeader;

    //Invoke the upload function.
    bool uploadSuccessful = await fileUploader(
        bytesPayload: fileByte,
        headers: headers,
        url: Uri.https(config.credentailsConfig.host, config.url, queryParams)
            .toString(),
        onSendComplete: (response) {
          //In the onsend complete, save the etag list and the part number
          //First get the etag.

          log('Chunk sent completely');

          log('This is the status code ${response.statusCode}\n');

          log('This is the response body${response.body}\n');
          log('This is the header${response.headers}\n');
          log('This the reason phrase ${response.reasonPhrase}\n');

          String etag = response.headers['etag'];
          _fileUploadController.addEtag([partNumber, etag]);

          onPartUploadComplete?.call(_fileUploadController.etagsLists,
              _fileUploadController.config.versionId);
        });

    return uploadSuccessful;
  }

  _shouldUpload(int currentNumberOfActiveUploads) {
    if (currentNumberOfActiveUploads < numberOfParallelUploads) {
      //The number of active uploads is lesser than the numberOfParallel Uploads.
      //Since it is lesser, start a new upload if one exists.

      _uploadPart();
    }
  }

  @override
  Future<bool> upload() async {
    //Just some default true statement since this function is not needed here.
    //This function is not used.

    _shouldUpload(_uploadingNumberNotifier.numberOfActiveRequests);

    return true;
  }

  Future<bool> _createMultipartUpload() async {
    // This function would prepare all that is needed for the request to be started.
    //It would initialize the required variables and it would also start a multipart request.

    //If it returns a bool, that means that the upload was successful.

    // final datetime = Utils.generateDatetime();
    // fileBytes = await file.readAsBytes();//I am doing away from this because of memory issues
    Completer<bool> createMultipartUploadComplete = Completer();

    await config.file.length().then(
      (value) async {
        _fileUploadController.fileLength = value;
        _fileUploadController.setChunkSize(); //Set the chunk size
        await _fileUploadController
            .createFileChunkIndexes(); //This is to get the indexes of the chunks

        await _fileUploadController.createMultipartUploadRequest().then(
          (value) {
            config.versionId = value;

            print('version id created $value');
            onVersionIdCreated?.call(value);
            createMultipartUploadComplete.complete(true);
          },
          onError: (error) {
            createMultipartUploadComplete.complete(false);
          },
        );
      },
      onError: (error) {
        createMultipartUploadComplete.complete(false);
      },
    );

    return createMultipartUploadComplete.future;
  }

  Future<bool> _resumeMultipartUpload() async {
    // This function would prepare all that is needed for the request to be resumed.
    //It would initialize the required variables

    //If it returns a bool, that means that the operation was successful.

    // final datetime = Utils.generateDatetime();
    // fileBytes = await file.readAsBytes();//I am doing away from this because of memory issues
    Completer<bool> createMultipartUploadComplete = Completer();

    await config.file.length().then(
      (value) async {
        _fileUploadController.fileLength = value;
        _fileUploadController.setChunkSize(); //Set the chunk size

        //Assign the etaglists
        _fileUploadController.addAllEtagLists(config.etagsLists);
        _fileUploadController.getPartsThatHaveBeenUploaded();
        await _fileUploadController
            .createFileChunkIndexes(); //This is to get the indexes of the chunks

        createMultipartUploadComplete.complete(true);
      },
      onError: (error) {
        createMultipartUploadComplete.complete(false);
      },
    );

    return createMultipartUploadComplete.future;
  }

  @override
  void dispose() {
    //Close the streams
    _uploadCompletedUpdate.close();
    _uploadProgress.close();
  }
}
