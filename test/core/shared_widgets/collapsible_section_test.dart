import 'package:balance/core/shared_widgets/collapsible_section.dart';
import 'package:balance/core/state/section_memory.dart';
import 'package:balance/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget section, {SectionMemory? memory}) {
  final page = MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: ListView(children: [section])),
  );
  return memory == null
      ? page
      : SectionMemoryScope(memory: memory, child: page);
}

const _section = CollapsibleSection(
  id: 'test.section',
  title: 'Availability',
  summary: '2 blocks · 4h free',
  child: Text('Block details'),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('starts closed with a large title, summary and chevron', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_section));

    expect(find.text('AVAILABILITY'), findsOneWidget);
    expect(find.text('2 blocks · 4h free'), findsOneWidget);
    expect(find.text('Block details'), findsNothing);
    expect(find.byTooltip('Show Availability'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    // Never a "+" that could be mistaken for adding something.
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('the chevron opens it and closes it again', (tester) async {
    await tester.pumpWidget(_host(_section));

    await tester.tap(find.byTooltip('Show Availability'));
    await tester.pumpAndSettle();
    expect(find.text('Block details'), findsOneWidget);
    expect(find.text('2 blocks · 4h free'), findsNothing);
    expect(find.byTooltip('Hide Availability'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);

    await tester.tap(find.byTooltip('Hide Availability'));
    await tester.pumpAndSettle();
    expect(find.text('Block details'), findsNothing);
  });

  testWidgets('tapping the title also toggles it', (tester) async {
    await tester.pumpWidget(_host(_section));
    await tester.tap(find.text('AVAILABILITY'));
    await tester.pumpAndSettle();
    expect(find.text('Block details'), findsOneWidget);
  });

  testWidgets('initiallyExpanded starts open', (tester) async {
    await tester.pumpWidget(
      _host(
        const CollapsibleSection(
          id: 'test.open',
          title: 'Capacity',
          initiallyExpanded: true,
          child: Text('Capacity details'),
        ),
      ),
    );
    expect(find.text('Capacity details'), findsOneWidget);
    expect(find.byTooltip('Hide Capacity'), findsOneWidget);
  });

  testWidgets('the choice is remembered and saved on the phone', (
    tester,
  ) async {
    final memory = SectionMemory();
    await tester.pumpWidget(_host(_section, memory: memory));
    await tester.tap(find.byTooltip('Show Availability'));
    await tester.pumpAndSettle();
    expect(memory.isExpanded('test.section'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('${SectionMemory.keyPrefix}test.section'), isTrue);

    // A new page with the same memory opens the section straight away.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(_section, memory: memory));
    expect(find.text('Block details'), findsOneWidget);
  });

  testWidgets('the description stays hidden until ? is tapped', (tester) async {
    await tester.pumpWidget(
      _host(
        const CollapsibleSection(
          id: 'test.help',
          title: 'Optional updates',
          help: 'Add detail to your Workload Overview. Skipping is fine.',
          child: Text('Inputs'),
        ),
      ),
    );
    const help = 'Add detail to your Workload Overview. Skipping is fine.';
    expect(find.text(help), findsNothing);

    await tester.tap(find.byTooltip('About Optional updates'));
    await tester.pumpAndSettle();
    expect(find.text(help), findsOneWidget);
    // Showing the description does not open the section.
    expect(find.text('Inputs'), findsNothing);

    await tester.tap(find.byTooltip('Hide info about Optional updates'));
    await tester.pumpAndSettle();
    expect(find.text(help), findsNothing);
  });

  test('load() restores saved section states', () async {
    SharedPreferences.setMockInitialValues({
      '${SectionMemory.keyPrefix}today.workload': true,
      '${SectionMemory.keyPrefix}quests.finished': false,
      'balance.theme_mode': 'light',
    });
    final memory = await SectionMemory.load();
    expect(memory.isExpanded('today.workload'), isTrue);
    expect(memory.isExpanded('quests.finished'), isFalse);
    expect(memory.isExpanded('today.tasks'), isNull);
  });
}
