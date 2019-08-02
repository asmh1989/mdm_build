import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:path/path.dart' as p;

import 'constant.dart';
import 'db.dart';
import 'framework/base.dart';
import 'framework/mdm41_framework.dart';
import 'framework/mdm42_framework.dart';
import 'framework/mdm4_framework.dart';
import 'framework/mdm_duoqi_framework.dart';
import 'framework/normal_framework.dart';
import 'model/build_model.dart';
import 'model/config_model.dart';
import 'params/build_params.dart';
import 'utils.dart';

DateTime _lastBuildTime = DateTime.now();

void _clearCache() async {
  var appPath = p.normalize(Utils.appPath(''));

  Directory apps = Directory(appPath);

  if (apps.existsSync()) {
    for (var file in apps.listSync()) {
      var name = p.basename(file.path);
      var data = await DBManager.findOne(
          Constant.tableBuild, where.eq(propBuildId, name));
      bool willDel = false;
      if (data != null) {
        BuildModel model = BuildModel.fromJson(data);
        if (model.status.code < BuildStatus.waiting.code) {
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

void _doTimerWork() async {
  if (DateTime.now().difference(_lastBuildTime).inMinutes.abs() < 3) {
    Utils.log('定时到, 开始查询 任务总数: ${await DBManager.count(Constant.tableBuild)}');
  }
  await Build.initConfig();
  await _clearCache();
  while (true) {
    int buildings = await DBManager.count(
        Constant.tableBuild, where.eq(propCode, BuildStatus.building.code));
    if (buildings < envConfig.max_build) {
      var data = await DBManager.findOne(
          Constant.tableBuild, where.eq(propCode, BuildStatus.waiting.code));

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
      Constant.tableBuild, where.eq(propCode, BuildStatus.building.code));
  for (var data in await builds.toList()) {
    BuildModel model = BuildModel.fromJson(data);
    if (model.date.difference(DateTime.now()).inMinutes.abs() > 20) {
      Utils.log(
          '发现异常的打包记录, ${model.build_id}, date: ${model.date.toIso8601String()}');
      Directory app = Directory(Utils.appPath(model.build_id));
      if (app.existsSync()) {
        app.deleteSync(recursive: true);
      }

      await Build._build(model);
    }
  }
}

class Build {
  static int MAX_BUILDS = 3000;

  static Map<String, BaseFramework> _frameworks = Map();

  static Future getBuild(String id) async {
    var data =
        await DBManager.findOne(Constant.tableBuild, where.eq(propBuildId, id));
    if (data != null) {
      BuildModel model = BuildModel.fromJson(data);
      return {
        "status": model.status.code,
        "msg": model.status.code == BuildStatus.failed.code
            ? BuildStatus.failed.msg
            : model.status.msg,
        "detail": model.status.msg,
        "downloadPath": model.status.code == BuildStatus.success.code
            ? '/app/package/${model.build_id}.apk'
            : ''
      };
    } else {
      return {
        "status": BuildStatus.illegal.code,
        "msg": BuildStatus.illegal.msg
      };
    }
  }

  static Future<List<Map>> getBuilds(
      {int status, int page = 0, int pageSize = 20}) async {
    if (page == null) page = 0;
    if (pageSize == null) pageSize = 20;

    if (pageSize < 1) pageSize = 1;

    var mm = where.skip(page * pageSize).limit(pageSize);
    if (status != null) {
      mm.eq(propCode, status);
    }
    var data = await DBManager.find(Constant.tableBuild, mm);

    List<Map> list = [];
    for (var d in await data.toList()) {
      list.add(BuildModel.fromJson(d).toJson());
    }

    return list;
  }

  static Future getCount([int status]) async {
    SelectorBuilder w;
    if (status != null) {
      w = where.eq(propCode, status);
    }
    return DBManager.count(Constant.tableBuild, w);
  }

  static void init() async {
    if (_frameworks.isEmpty) {
      List<BaseFramework> lists = List();
      lists.add(MDM4Framework());
      lists.add(MDM41Framework());
      lists.add(MDM42Framework());
      lists.add(NormalFramework());
      lists.add(MDMDuoQiFramework());

      for (BaseFramework framework in lists) {
        _frameworks[framework.getName()] = framework;
      }

      lists.clear();
    }
    await initConfig();

    Utils.log('env_config: ${json.encode(envConfig.toJson())}');

    Timer.periodic(Duration(seconds: 60), (Timer t) => _doTimerWork());

    Timer(Duration(seconds: 2), () => _doTimerWork());
  }

  static Future<Map> initConfig([Map<String, dynamic> config]) async {
    var data = await DBManager.findOne(Constant.tableConfig);
    envConfig = ConfigModel.fromJson(data ?? {});

    if (data == null) {
      await DBManager.save(Constant.tableConfig, data: envConfig.toJson());
    }

    if (config != null) {
      envConfig.merge(ConfigModel(
          max_build: config[propMaxBuild],
          android_home: config[propAndroidHome],
          java_home: config[propJavaHome],
          cache_home: config[propCacheHome],
          zkm_jar: config[propZkmJar],
          white_ips: config[propWhiteIps]));
      Utils.log('env_config: ${json.encode(envConfig.toJson())}');
      await DBManager.save(Constant.tableConfig, data: envConfig.toJson());
    }

    return envConfig.toJson();
  }

  static bool isWhiteIp(String ip) {
    if (envConfig.white_ips.isNotEmpty) {
      return envConfig.white_ips.contains(ip);
    } else {
      return true;
    }
  }

  static Future<bool> rebuild(String id) async {
    var data =
        await DBManager.findOne(Constant.tableBuild, where.eq(propBuildId, id));
    if (data != null) {
      BuildModel model = BuildModel.fromJson(data);
      _build(model);
      return true;
    } else {
      return false;
    }
  }

  static Future<String> start(BuildParams params) async {
    String key = Utils.newKey();

    var model = BuildModel(build_id: key, params: params);

    await DBManager.save(Constant.tableBuild,
        id: propBuildId, data: model.toJson());

    int now_builds = await DBManager.count(
        Constant.tableBuild, where.eq(propCode, BuildStatus.building.code));

    if (now_builds < envConfig.max_build) {
      await _build(model);
    } else {
      Utils.log(
          '$key need waiting... building: $now_builds, max_build:${envConfig.max_build}');
    }

    return key;
  }

  static void _build(BuildModel model) async {
    Utils.log('${model.build_id} .... 进入打包状态');
    _lastBuildTime = DateTime.now();
    BaseFramework framework = _frameworks[model.params.configs.framework];
    if (framework == null) {
      model.status = BuildStatus.newFailed(
          '不支持的 framework: ${model.params.configs.framework}');
      await DBManager.save(Constant.tableBuild,
          id: propBuildId, data: model.toJson());
    } else {
      model.status = BuildStatus.building;
      await DBManager.save(Constant.tableBuild,
          id: propBuildId, data: model.toJson());
      framework.build(model);
    }
  }
}
