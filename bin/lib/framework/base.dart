import '../params/build_params.dart';
import 'dart:async';
abstract class BaseFramework {
  /// 编译框架的命名
  String getName();

  /// 打包过程
  FutureOr<String> build(BuildParams params);

}