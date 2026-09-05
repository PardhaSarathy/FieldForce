import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/core/theme/app_colors.dart';
import 'package:pharmaconnect/core/theme/app_theme.dart';
import 'package:pharmaconnect/shared/widgets/inputs.dart';

/// Options open in a bottom sheet, not in a menu anchored to the field.
///
/// A rep fills these forms one-handed in the street. An anchored menu opens
/// wherever the field sits — often the top of a long form, out of thumb reach —
/// and can open behind the keyboard mid-edit. This is the behaviour every one
/// of the app's ~27 dropdowns inherits, so it is worth asserting rather than
/// eyeballing.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<String> items,
    String? value,
    ValueChanged<String?>? onChanged,
    String? Function(String?)? validator,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: DropdownField<String>(
              label: 'Work type',
              items: items,
              itemLabel: (s) => s,
              value: value,
              onChanged: onChanged,
              validator: validator,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping the field opens a sheet, and picking closes it',
      (tester) async {
    String? picked;
    await pump(
      tester,
      items: const ['Field work', 'Office', 'Leave'],
      onChanged: (v) => picked = v,
    );

    // Closed: the hint shows and no option is on screen.
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Office'), findsNothing);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    // Open: every option is reachable, under a title naming the field.
    expect(find.text('Field work'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);

    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();

    expect(picked, 'Office');
    expect(find.text('Leave'), findsNothing, reason: 'the sheet should close');
  });

  testWidgets('a long list gets a search box; a short one does not',
      (tester) async {
    await pump(tester, items: const ['One', 'Two', 'Three']);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchField), findsNothing,
        reason: 'searching three options is more work than reading them');

    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();

    await pump(tester, items: List.generate(12, (i) => 'Area ${i + 1}'));
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchField), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Area 11');
    await tester.pumpAndSettle();

    // Scoped to the rows: the search box now contains the query too, so a bare
    // text finder matches it as well and proves nothing about the filtering.
    expect(find.widgetWithText(ListTile, 'Area 11'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Area 1'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Area 2'), findsNothing);
  });

  testWidgets('the selected option is marked, and by more than colour',
      (tester) async {
    await pump(tester, items: const ['Field work', 'Office'], value: 'Office');

    // Closed, it shows the selection rather than the hint.
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Select'), findsNothing);

    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('validators still run — the FormField underneath is real',
      (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Form(
            key: key,
            child: DropdownField<String>(
              label: 'Work type',
              items: const ['Field work'],
              itemLabel: (s) => s,
              validator: (v) => v == null ? 'Pick a work type' : null,
            ),
          ),
        ),
      ),
    );

    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Pick a work type'), findsOneWidget);
  });

  testWidgets('an empty list does not open an empty sheet', (tester) async {
    await pump(tester, items: const []);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    // Nothing to choose from, so nothing opens — rather than a sheet that
    // slides up to say it is empty.
    expect(find.text('Nothing to choose from yet.'), findsNothing);
  });

  group('SegmentedField', () {
    testWidgets('shows every option without a tap', (tester) async {
      var value = 'Unlisted';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SegmentedField<String>(
                label: 'Category',
                options: const ['Listed', 'Unlisted'],
                itemLabel: (s) => s,
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );

      // The whole point: both answers are on screen, no tap spent revealing
      // them and none spent closing anything.
      expect(find.text('Listed'), findsOneWidget);
      expect(find.text('Unlisted'), findsOneWidget);
      // The selected one is the filled pill, which is what a filter chip does
      // three screens away. It used to be an `AppCard` per option carrying a
      // Material radio ring — a second indicator saying what the fill already
      // said, and the loudest thing in the row.
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);

      int filled() => tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.style?.color == AppColors.textOnBrand)
          .length;

      expect(filled(), 1, reason: 'exactly one answer is chosen');

      await tester.tap(find.text('Listed'));
      await tester.pumpAndSettle();
      expect(value, 'Listed');

      // Still exactly one — a radio, not a checkbox.
      expect(filled(), 1);
    });
  });
}
