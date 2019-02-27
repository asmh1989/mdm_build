import 'dart:async';

import '../model/build_model.dart';

abstract class BaseFramework {
  /// 打包过程
  FutureOr<void> build(BuildModel params);

  /// 编译框架的命名
  String getName();
}
