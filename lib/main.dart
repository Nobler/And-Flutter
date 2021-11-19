import 'dart:async';

import 'package:android_view/binding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class TextView extends SingleChildRenderObjectView {
  TextView() : super(null);

  String? _text;

  String? get text => _text;

  set text(String? text) {
    _text = text;
    invalidate();
  }

  @override
  RenderParagraph createRenderObject(Context context) {
    return RenderParagraph(
      TextSpan(text: _text),
      textDirection: TextDirection.ltr,
    );
  }

  @override
  void updateRenderObject(Context context, RenderParagraph renderObject) {
    renderObject..text = TextSpan(text: _text);
  }
}

void main() {
  final textView = TextView();

  runAndroidApp(textView);

  Timer(Duration(seconds: 1), () {
    textView.text = 'Hello, world';
  });
}
