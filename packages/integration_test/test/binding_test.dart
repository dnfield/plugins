import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:integration_test/integration_test.dart';
import 'package:integration_test/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart' as vm;

void main() async {
  late Future<Map<String, dynamic>> request;

  group('Test Integration binding', () {
    late FakeVmService fakeVmService;
    late IntegrationTestWidgetsFlutterBinding integrationBinding;

    setUp(() {
      fakeVmService = FakeVmService();
      integrationBinding =
          IntegrationTestWidgetsFlutterBinding.ensureInitialized(
        vmService: fakeVmService,
      ) as IntegrationTestWidgetsFlutterBinding;

      request = integrationBinding.callback(<String, String>{
        'command': 'request_data',
      });
    });

    testWidgets('Run Integration app', (WidgetTester tester) async {
      runApp(MaterialApp(
        home: Text('Test'),
      ));
      expect(tester.binding, integrationBinding);
      integrationBinding.reportData = <String, dynamic>{'answer': 42};
    });

    testWidgets('setSurfaceSize works', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Center(child: Text('Test'))));

      final Size windowCenter = tester.binding.window.physicalSize /
          tester.binding.window.devicePixelRatio /
          2;
      final double windowCenterX = windowCenter.width;
      final double windowCenterY = windowCenter.height;

      Offset widgetCenter = tester.getRect(find.byType(Text)).center;
      expect(widgetCenter.dx, windowCenterX);
      expect(widgetCenter.dy, windowCenterY);

      await tester.binding.setSurfaceSize(const Size(200, 300));
      await tester.pump();
      widgetCenter = tester.getRect(find.byType(Text)).center;
      expect(widgetCenter.dx, 100);
      expect(widgetCenter.dy, 150);

      await tester.binding.setSurfaceSize(null);
      await tester.pump();
      widgetCenter = tester.getRect(find.byType(Text)).center;
      expect(widgetCenter.dx, windowCenterX);
      expect(widgetCenter.dy, windowCenterY);
    });

    testWidgets('Test traceAction', (WidgetTester tester) async {
      await integrationBinding.enableTimeline();
      await integrationBinding.traceAction(() async {});
      expect(integrationBinding.reportData, isNotNull);
      expect(integrationBinding.reportData!.containsKey('timeline'), true);
      expect(
        json.encode(integrationBinding.reportData!['timeline']),
        json.encode(fakeVmService.kTimelines),
      );
    });
  });

  tearDownAll(() async {
    // This part is outside the group so that `request` has been compeleted as
    // part of the `tearDownAll` registerred in the group during
    // `IntegrationTestWidgetsFlutterBinding` initialization.
    final Map<String, dynamic> response =
        (await request)['response'] as Map<String, dynamic>;
    final String message = response['message'] as String;
    Response result = Response.fromJson(message);
    assert(result.data!['answer'] == 42);
  });
}

class FakeVmService extends Fake implements vm.VmService {
  final vm.Timeline kTimelines = vm.Timeline(
    traceEvents: <vm.TimelineEvent>[],
    timeOriginMicros: 100,
    timeExtentMicros: 200,
  );

  final List<int> clockTimes = <int>[100, 200];

  @override
  Future<vm.Timeline> getVMTimeline(
      {int? timeOriginMicros, int? timeExtentMicros}) async {
    return kTimelines;
  }

  @override
  Future<vm.Timestamp> getVMTimelineMicros() async {
    return vm.Timestamp(timestamp: clockTimes.removeAt(0));
  }
}
