import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sda/src/app/app.dart';
import 'package:sda/src/app/providers.dart';
import 'package:sda/src/services/storage_provider.dart';

void main() {
  testWidgets('app boots to empty home with in-memory storage', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(MemoryStorageProvider()),
          // Avoid real network and periodic timers in the widget test.
          timeAlignerProvider.overrideWithValue(() async {}),
          tickProvider.overrideWith((ref) => Stream<int>.value(1700000000)),
        ],
        child: const SdaApp(),
      ),
    );

    // Let the async bootstrap (load store) settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Empty store -> home screen with the "no accounts" message and an add FAB.
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
