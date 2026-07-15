import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../connect/speed_test_card.dart';

class NetworkTestPage extends StatelessWidget {
  const NetworkTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.speedTestTitle)),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SpeedTestCard(),
      ),
    );
  }
}
