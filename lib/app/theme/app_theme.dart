import 'package:flutter/cupertino.dart';
import 'glass.dart';

final appCupertinoTheme = CupertinoThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.black,
  barBackgroundColor: AppColors.black,
  primaryColor: AppColors.white,
  textTheme: CupertinoTextThemeData(
    textStyle: TextStyle(
      color: AppColors.white,
      fontFamily: '.SF Pro Text',
      fontSize: 16,
    ),
    navTitleTextStyle: TextStyle(
      color: AppColors.white,
      fontFamily: '.SF Pro Display',
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
  ),
);

class AppText {
  static const display = TextStyle(
    color: AppColors.white,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.05,
  );

  static const title = TextStyle(
    color: AppColors.white,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const body = TextStyle(
    color: AppColors.white,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    color: AppColors.dim,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const number = TextStyle(
    color: AppColors.white,
    fontSize: 64,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    height: 1,
  );
}
