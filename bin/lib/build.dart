import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:path/path.dart' as P;

import 'framework/base.dart';

import 'framework/mdm4_framework.dart';
import 'framework/mdm41_framework.dart';
import 'framework/mdm42_framework.dart';
import 'framework/normal_framework.dart';

import 'params/build_params.dart';
import 'model/build_model.dart';
import 'model/config_model.dart';
import 'utils.dart';
import 'constant.dart';
import 'db.dart';

DateTime _last_build = DateTime.now();

void _doTimerWork() async {
  if (DateTime.now().difference(_last_build).inMinutes.abs() < 3) {
    Utils.log('定时到, 开始查询 任务总数: ${await DBManager.count(Constant.TABLE_BUILD)}');
  }
  await Build.initConfig();
  await _clearCache();
  while (true) {
    int buildings = await DBManager.count(
        Constant.TABLE_BUILD, where.eq(PROP_CODE, BuildStatus.BUILDING.code));
    if (buildings < env_config.max_build) {
      var data = await DBManager.findOne(
          Constant.TABLE_BUILD, where.eq(PROP_CODE, BuildStatus.WAITING.code));

      if (data != null && data.isNotEmpty) {
        BuildModel model = BuildModel.fromJson(data);
        await Build._build(model);
      } else {
        break;
      }
    } else {
      break;
    }
  }

  var builds = await DBManager.find(
      Constant.TABLE_BUILD, where.eq(PROP_CODE, BuildStatus.BUILDING.code));
  for (var data in await builds.toList()) {
    BuildModel model = BuildModel.fromJson(data);
    if (model.date.difference(DateTime.now()).inMinutes.abs() > 20) {
      Utils.log(
          '发现异常的打包记录, ${model.build_id}, date: ${model.date.toIso8601String()}');
      Directory app = new Directory(Utils.appPath(model.build_id));
      if (app.existsSync()) {
        app.deleteSync(recursive: true);
      }

      await Build._build(model);
    }
  }
}

void _clearCache() async {
  var appPath = P.normalize(Utils.appPath(''));

  Directory apps = new Directory(appPath);

  if (apps.existsSync()) {
    for (var file in apps.listSync()) {
      var name = P.basename(file.path);
      var data = await DBManager.findOne(
          Constant.TABLE_BUILD, where.eq(PROP_BUILD_ID, name));
      bool willDel = false;
      if (data != null) {
        BuildModel model = BuildModel.fromJson(data);
        if (model.status.code < BuildStatus.WAITING.code) {
          willDel = true;
        }
      }

      if (willDel) {
        var stat = file.statSync();

        /// 大于三天就开始清理编译目录
        if (stat.modified.difference(DateTime.now()).inDays.abs() > 3) {
          Utils.log('清理缓存... ${file.path}, ${stat.modified.toIso8601String()}');
          file.deleteSync(recursive: true);
          break;
        }
      }
    }
  }
}

class Build {
  static int MAX_BUILDS = 3000;

  static Map<String, BaseFramework> _frameworks = new Map();

  static void init() async {
    if (_frameworks.isEmpty) {
      List<BaseFramework> lists = new List();
      lists.add(new MDM4Framework());
      lists.add(new MDM41Framework());
      lists.add(new MDM42Framework());
      lists.add(new NormalFramework());

      for (BaseFramework framework in lists) {
        _frameworks[framework.getName()] = framework;
      }

      lists.clear();
    }
    await initConfig();

    Utils.log('env_config: ${json.encode(env_config.toJson())}');

    new Timer.periodic(new Duration(seconds: 60), (Timer t) => _doTimerWork());

    new Timer(Duration(seconds: 2), () => _doTimerWork());
  }

  static Future<Map> initConfig([Map<String, dynamic> config]) async {
    var data = await DBManager.findOne(Constant.TABLE_CONFIG);
    env_config = ConfigModel.fromJson(data ?? {});

    if (data == null) {
      await DBManager.save(Constant.TABLE_CONFIG, data: env_config.toJson());
    }

    if (config != null) {
      env_config.merge(new ConfigModel(
          max_build: config[PROP_MAX_BUILD],
          android_home: config[PROP_ANDROID_HOME],
          java_home: config[PROP_JAVA_HOME],
          cache_home: config[PROP_CACHE_HOME],
          zkm_jar: config[PROP_ZKM_JAR],
          white_ips: config[PROP_WHITE_IPS]));
      Utils.log('env_config: ${json.encode(env_config.toJson())}');
      await DBManager.save(Constant.TABLE_CONFIG, data: env_config.toJson());
    }

    return env_config.toJson();
  }

  static void _build(BuildModel model) async {
    Utils.log('${model.build_id} .... 进入打包状态');
    _last_build = DateTime.now();
    BaseFramework framework = _frameworks[model.params.framework];
    if (framework == null) {
      model.status =
          BuildStatus.newFailed('不支持的 framework: ${model.params.framework}');
      await DBManager.save(Constant.TABLE_BUILD,
          id: PROP_BUILD_ID, data: model.toJson());
    } else {
      model.status = BuildStatus.BUILDING;
      await DBManager.save(Constant.TABLE_BUILD,
          id: PROP_BUILD_ID, data: model.toJson());
      framework.build(model);
    }
  }

  static Future<String> start(BuildParams params) async {
    String key = Utils.newKey();

    var model = new BuildModel(build_id: key, params: params);

    await DBManager.save(Constant.TABLE_BUILD,
        id: PROP_BUILD_ID, data: model.toJson());

    int now_builds = await DBManager.count(
        Constant.TABLE_BUILD, where.eq(PROP_CODE, BuildStatus.BUILDING.code));

    if (now_builds < env_config.max_build) {
      await _build(model);
    } else {
      Utils.log(
          '$key need waiting... building: $now_builds, max_build:${env_config.max_build}');
    }

    return key;
  }

  static Future<List<Map>> getBuilds(
      {int status, int page = 0, int pageSize = 20}) async {
    if (page == null) page = 0;
    if (pageSize == null) pageSize = 20;

    if (pageSize < 1) pageSize = 1;

    var mm = where.skip(page * pageSize).limit(pageSize);
    if (status != null) {
      mm.eq(PROP_CODE, status);
    }
    var data = await DBManager.find(Constant.TABLE_BUILD, mm);

    List<Map> list = [];
    for (var d in await data.toList()) {
      list.add(BuildModel.fromJson(d).toJson());
    }

    return list;
  }

  static Future getBuild(String id) async {
    var data = await DBManager.findOne(
        Constant.TABLE_BUILD, where.eq(PROP_BUILD_ID, id));
    if (data != null) {
      return BuildModel.fromJson(data).toJson();
    } else {
      return null;
    }
  }

  static Future getCount([int status]) async {
    var w;
    if (status != null) {
      w = where.eq(PROP_CODE, status);
    }
    return DBManager.count(Constant.TABLE_BUILD, w);
  }

  static bool isWhiteIp(String ip) {
    if (env_config.white_ips.isNotEmpty) {
      return env_config.white_ips.contains(ip);
    } else {
      return true;
    }
  }
}
