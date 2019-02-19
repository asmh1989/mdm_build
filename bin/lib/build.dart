import 'package:mongo_dart/mongo_dart.dart' ;

import 'framework/base.dart';

import 'framework/mdm4_framework.dart';
import 'framework/mdm41_framework.dart';
import 'framework/mdm42_framework.dart';

import 'params/build_params.dart';
import 'model/build_model.dart';
import 'model/config_model.dart';
import 'utils.dart';
import 'constant.dart';
import 'db.dart';

class Build {

  static int MAX_BUILDS = 3000;

  static Map<String, BaseFramework> _frameworks = new Map();

  static void init() async {
    if(_frameworks.isEmpty){
      List<BaseFramework> lists = new List();
      lists.add(new MDM4Framework());
      lists.add(new MDM41Framework());
      lists.add(new MDM42Framework());

      for(BaseFramework framework in lists){
        _frameworks[framework.getName()] = framework;
      }

      lists.clear();
    }
    await initConfig();

  }

  static Future<Map> initConfig([Map<String, dynamic> config]) async {
    var data = await DBManager.findOne(Constant.TABLE_CONFIG);
    env_config = ConfigModel.fromJson(data??{});

    if(config != null){
      env_config.merge(new ConfigModel(
          max_build: config[PROP_MAX_BUILD],
          android_home: config[PROP_ANDROID_HOME],
          java_home: config[PROP_JAVA_HOME],
          cache_home: config[PROP_CACHE_HOME],
          zkm_jar: config[PROP_ZKM_JAR]
      ));

      await DBManager.save(Constant.TABLE_CONFIG, data:env_config.toJson());
    }

    return  env_config.toJson();
  }

  static void _build(BaseFramework framework, BuildModel model) async {
    model.status = BuildStatus.BUILDING;
    await DBManager.save(Constant.TABLE_BUILD, id:PROP_BUILD_ID, data:model.toJson());
    framework.build(model);
  }

  static Future<String> start(BuildParams params)  async {
    BaseFramework framework = _frameworks[params.framework];
    if(framework == null){
      throw new Exception('不支持的 framework: ${params.framework}');
    }
    String key = Utils.newKey();

    var model = new BuildModel(build_id: key, params: params);

    await DBManager.save(Constant.TABLE_BUILD, id: PROP_BUILD_ID,data: model.toJson());

    int now_builds = await DBManager.count(Constant.TABLE_BUILD, where.eq(PROP_CODE, BuildStatus.BUILDING.code));

    if(now_builds < env_config.max_build){
      _build(framework, model);
    } else {
      Utils.log('$key need waiting... building: $now_builds, max_build:${env_config.max_build}');
    }

    return key;
  }

}