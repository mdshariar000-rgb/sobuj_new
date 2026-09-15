package site.codecell.shobuj_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth's Android
// implementation, which needs a FragmentActivity host to show the biometric prompt.
class MainActivity : FlutterFragmentActivity()
