import 'package:state_notifier/state_notifier.dart';

class UploadingNumberNotifier extends StateNotifier<int> {
  //Basically, this would take note of the number of currently active requests.
  //If the number of currently added requests is less than the set number of
  //Parallel requests, the upload function is called.
  UploadingNumberNotifier() : super(0);

  int get numberOfActiveRequests => state;

  void oneUploadDone() {
    //This  would be called when maybe a request fails or a request was completed.

    state -= 1;
  }

  void oneUploadAdded() {
    //This  would be called when maybe a request is added

    state += 1;
  }
}
