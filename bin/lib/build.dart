import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart' ;

import 'framework/base.dart';
import 'framework/mdm4_framework.dart';
import 'params/build_params.dart';
import 'model/build_model.dart';
import 'utils.dart';
import 'constant.dart';
import 'db.dart';

class Build {

  static int MAX_BUILDS = 1;
  static int _builds = 0;

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

  static void _build(BaseFramework framework, BuildModel model) async {
    String appPath = '${Utils.cachePath}/${model.build_id}';

    Directory dir = new Directory(appPath);
    if(dir.existsSync()){
      dir.deleteSync();
    }
    dir.createSync(recursive: true);

    model.status = BuildStatus.BUILDING;
    await DBManager.save(Constant.TABLE_BUILD, 'build_id', model.toJson());
    framework.build(model);
  }

  static Future<String> start(BuildParams params)  async {
    BaseFramework framework = _frameworks[params.framework];
    if(framework == null){
      throw new Exception('不支持的 framework: ${params.framework}');
    }
    String key = Utils.newKey();

    var model = new BuildModel(build_id: key, params: params);

    await DBManager.save(Constant.TABLE_BUILD, 'build_id', model.toJson());

    int now_builds = await DBManager.count(Constant.TABLE_BUILD, where.eq('code', BuildStatus.BUILDING.code));

    if(now_builds < MAX_BUILDS){
      _build(framework, model);
    }

    return key;
  }

}