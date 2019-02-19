import 'dart:async';
import 'dart:io';
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

void _doTimerWork()  async {
  Utils.log('定时到, 开始查询 任务总数: ${await DBManager.count(Constant.TABLE_BUILD)}');
  await Build.initConfig();
  while(true) {
    int buildings = await DBManager.count(Constant.TABLE_BUILD,
        where.eq(PROP_CODE, BuildStatus.BUILDING.code));
    if (buildings < env_config.max_build) {
      var data = await DBManager.findOne(Constant.TABLE_BUILD,
          where.eq(PROP_CODE, BuildStatus.WAITING.code));

      if(data != null && data.isNotEmpty){
        BuildModel model = BuildModel.fromJson(data);
        await Build._build(model);
      } else {
        break;
      }
    } else {
      break;
    }
  }

  var builds = await DBManager.find(Constant.TABLE_BUILD, where.eq(PROP_CODE, BuildStatus.BUILDING.code));
  for(var data in await builds.toList()){
    BuildModel model = BuildModel.fromJson(data);

    var now = DateTime.now().millisecondsSinceEpoch;
    if(now -  model.date.millisecondsSinceEpoch> 20*60*1000){
      Utils.log('发现异常的打包记录, ${model.build_id}, date: ${model.date.toIso8601String()}');
      Directory app = new Directory(Utils.appPath(model.build_id));
      if(app.existsSync()){
        app.deleteSync(recursive: true);
      }

      await Build._build(model);
    }
  }
}

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

    new Timer.periodic(new Duration(seconds: 60), (Timer t)=> _doTimerWork());

    new Timer(Duration(seconds: 2), () => _doTimerWork());

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

  static void _build(BuildModel model) async {
    BaseFramework framework = _frameworks[model.params.framework];
    if(framework == null){
      model.status = BuildStatus.newFailed('不支持的 framework: ${model.params.framework}');
      await DBManager.save(Constant.TABLE_BUILD, id:PROP_BUILD_ID, data:model.toJson());
    } else {
      model.status = BuildStatus.BUILDING;
      await DBManager.save(Constant.TABLE_BUILD, id:PROP_BUILD_ID, data:model.toJson());
      framework.build(model);
    }
  }

  static Future<String> start(BuildParams params)  async {

    String key = Utils.newKey();

    var model = new BuildModel(build_id: key, params: params);

    await DBManager.save(Constant.TABLE_BUILD, id: PROP_BUILD_ID,data: model.toJson());

    int now_builds = await DBManager.count(Constant.TABLE_BUILD, where.eq(PROP_CODE, BuildStatus.BUILDING.code));

    if(now_builds < env_config.max_build){
      await _build(model);
    } else {
      Utils.log('$key need waiting... building: $now_builds, max_build:${env_config.max_build}');
    }

    return key;
  }

  static Future<List<Map>> getBuilds({
    int status,
    int page = 0,
    int pageSize = 20
  }) async{

    if(page == null) page = 0;
    if(pageSize == null) pageSize = 20;

    if(pageSize < 1) pageSize = 1;

    var mm = where.skip(page * pageSize).limit(pageSize);
    if(status != null){
      mm.eq(PROP_CODE, status);
    }
    var data = await DBManager.find(Constant.TABLE_BUILD, mm);

    List<Map> list = [];
    for(var d in await data.toList()){
      list.add(BuildModel.fromJson(d).toJson());
    }

    return list;

  }
}