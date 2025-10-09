import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
void showLoaderDialog(BuildContext context) {
  showDialog(context: context, builder: (context) =>  Center(child: LoadingAnimationWidget.hexagonDots(color: Colors.blue, size: 50,),));
}

void hideLoaderDialog(BuildContext context) {
  Navigator.pop(context);
}

