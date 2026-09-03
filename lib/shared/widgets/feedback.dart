import 'package:flutter/material.dart';

/// Says that a control is real but its backing service is not in this build.
///
/// The alternative, which this replaced in nineteen places, was
/// `onPressed: () {}` — an enabled button that swallows the tap. On a demo
/// that is indistinguishable from a broken app: the user presses Call, nothing
/// happens, and the reasonable conclusion is that the app is broken rather
/// than that telephony is not wired up yet.
///
/// Answering is the point. What it says matters less than that it says
/// something.
void showComingWithBackend(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what arrives with the backend.')));
}
