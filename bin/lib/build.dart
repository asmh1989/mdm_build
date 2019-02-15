import 'dart:io';

import 'framework/base.dart';
import 'framework/mdm4_framework.dart';
import 'params/build_params.dart';
import 'model/build_model.dart';
import 'utils.dart';
import 'constant.dart';
import 'db.dart';

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

  static Future<String> start(BuildParams params)  async {
    BaseFramework framework = _frameworks[params.framework];
    if(framework == null){
      throw new Exception('不支持的 framework: ${params.framework}');
    }
    String key = Utils.newKey();

    String appPath = '${Utils.cachePath}/${key}';

    Directory dir = new Directory(appPath);
    if(dir.existsSync()){
      dir.deleteSync();
    }
    dir.createSync(recursive: true);

    var model = new BuildModel(build_id: key, params: params);

    await DBManager.save(Constant.TABLE_BUILD, 'build_id', model.toJson());

    framework.build(model);

    return key;
  }

}