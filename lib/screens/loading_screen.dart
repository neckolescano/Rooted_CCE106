import 'package:flutter/material.dart';
import '../widgets/clock_intro.dart';

/// The start-up screen: the kuwaGO opening (widgets/clock_intro.dart).
///
/// It is laid over the real app (see BootApp in main.dart) rather than
/// being a page inside it, so when the pixel circle opens out of the clock
/// O, the app is really there underneath. No loading bar — start-up
/// happens quietly behind it.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, required this.appReady, required this.onRevealed});

  final bool appReady;
  final VoidCallback onRevealed;

  @override
  Widget build(BuildContext context) {
    // This sits outside any MaterialApp, so give it screen size + text
    // direction itself.
    return MediaQuery.fromView(
      view: View.of(context),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ClockIntro(appReady: appReady, onRevealed: onRevealed),
      ),
    );
  }
}
