import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/screens/splash/splash_screen.dart';

void main() {
  testWidgets(
    'the logo circle and progress bar are horizontally centered on screen, not flush left',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      // The progress bar is indeterminate and animates forever, so
      // pumpAndSettle would time out — a single pump is enough for layout.
      await tester.pump(const Duration(milliseconds: 100));

      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      const tolerance = 1.0;

      // The 96x96 logo circle has a font-independent explicit size, so its
      // center is a reliable centering check even without real fonts loaded.
      final iconCircle = find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.maxWidth == 96,
      );
      final iconCenter = tester.getCenter(iconCircle);
      expect(iconCenter.dx, closeTo(screenWidth / 2, tolerance));

      // Same reasoning for the 120-wide progress bar track.
      final progressBar = find.byType(LinearProgressIndicator);
      final progressCenter = tester.getCenter(progressBar);
      expect(progressCenter.dx, closeTo(screenWidth / 2, tolerance));
    },
  );
}
