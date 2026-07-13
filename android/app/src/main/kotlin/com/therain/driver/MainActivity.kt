package com.therain.driver

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (biometric login) requires a FragmentActivity host, not the
// plain FlutterActivity — see https://pub.dev/packages/local_auth setup.
class MainActivity : FlutterFragmentActivity()
