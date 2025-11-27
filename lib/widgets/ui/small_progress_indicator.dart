import 'package:flutter/material.dart';

class SmallProgressIndicator extends StatelessWidget {
  const SmallProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2)));
  }
}
