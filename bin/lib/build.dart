import 'framework/base.dart';
import 'framework/mdm4_framework.dart';
import 'params/build_params.dart';
class Build {

  static Map<String, BaseFramework> _frameworks = new Map();

  static void init() {
    if(_frameworks.isEmpty){
      List<BaseFramework> lists = new List();
      lists.add(new MDM4Framework());

      for(BaseFramework framework in lists){
        _frameworks[framework.getName()] = framework;
      }

      lists.clear();
    }
  }

  static Future<String> start(BuildParams params) async {
    BaseFramework framework = _frameworks[params.framework];
    if(framework == null){
      throw new Exception('不支持的 framework: ${params.framework}');
    }

    return await framework.build(params);
  }

}