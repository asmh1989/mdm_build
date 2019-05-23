import 'dart:async';
import 'dart:io';

import 'package:shell/shell.dart';
import 'package:xml/xml.dart';

import '../constant.dart';
import '../db.dart';
import '../model/build_model.dart';
import '../shell.dart';
import '../utils.dart';
import 'base.dart';
import 'create_icon.dart';
import 'update_androidmanifest.dart';

class MDM4Framework implements BaseFramework {
  String sourceName = 'source';

  void afterBuild(BuildModel model, String source) async {
    var savePath = Utils.packagePath(model.build_id) + '.apk';
    var releasePackage = '$source/app/build/outputs/apk/app-release.apk';
    if (!File(releasePackage).existsSync()) {
      releasePackage = '$source/app/build/outputs/apk/release/app-release.apk';
      if (!File(releasePackage).existsSync()) {
        throw 'apk 包不见了';
      }
    }

    Shell2 shell = Shell2(workDir: source);

    if (File('$source/resign.sh').existsSync()) {
      Utils.log('发现重新签名脚步...');
      var result = await shell.run('sh $source/resign.sh');
      if (result.exitCode != 0) {
        throw '重新签名失败';
      }
    }

    await shell.run('cp  $releasePackage $savePath');
  }

  @override
  FutureOr<void> build(BuildModel model) async {
    String appPath = Utils.appPath(model.build_id);
    String source = '$appPath/$sourceName';

    b() async {
      var build_time = DateTime.now();

      /// mdm_4 需要在as工程下进行编译, 所以需要先下载模板
      await preSource(model, appPath);

      /// 准备工作, 下载实际的svn代码, 并把需要的代码合并到模板工程中
      await prepare(model, source);

      /// 修改app icon
      await changeRes(model, appPath, source);

      /// 修改配置
      await changeConfig(model, source);

      /// 删除version 配置
      await changeBuildGradle(model, source);

      /// 开始编译
      await realBuild(model, source);

      /// 编译后处理
      await afterBuild(model, source);

      model.status = BuildStatus.success;
      model.build_time = DateTime.now().difference(build_time).inSeconds.abs();
      await DBManager.save(Constant.tableBuild,
          id: propBuildId, data: model.toJson());
      Utils.log('${model.build_id}, 打包结束.....');
    }

    runZoned(() {
      b();
    }, onError: (e, stacks) async {
      Utils.log(e);
      print(stacks);
      model.status = BuildStatus.newFailed(e.toString());
      await DBManager.save(Constant.tableBuild,
          id: propBuildId, data: model.toJson());
    });
  }

  void changeConfig(BuildModel model, String source) async {
    var tmpSrc = getTmpSrc(source);
    Shell2 shell = Shell2(env: {'LANGUAGE': 'en_us'});

    var app = model.params.app_info;
    String manifestFilePath = source + '/app/src/main/AndroidManifest.xml';
    final file = File(manifestFilePath);
    if (file.existsSync()) {
      var meta = Map<String, String>();

      meta.addAll(app.meta);

      if (Directory(tmpSrc).existsSync()) {
        var svn_version = model.params.app_info.svn_version;
        if (svn_version == null) {
          var result = await shell.run(
              "svn info | awk '\$3==\"Rev:\" {print \$4}'", tmpSrc);
          svn_version = int.parse(result.stdout.toString().trim());
        }
        Utils.log('svn_version = $svn_version');
        meta['svn-version'] = '$svn_version';
      } else {
        if(Directory(source +'/.git').existsSync()){
          var result = await shell.run(
              "git rev-parse HEAD", source);

          var git_version = result.stdout.toString().trim();

          Utils.log('git_version = $git_version');
          meta['git-version'] = git_version;
        }
      }

      Map<String, String> attrs = Map();

      if (app.app_name != null && app.app_name.isNotEmpty) {
        attrs['android:label'] = app.app_name;
      }

      if (app.app_icon != null && app.app_icon.isNotEmpty) {
        attrs['android:icon'] = '@drawable/auto_build_icon';
      }

      var doc = parse(await file.readAsString());

      var update = UpdateAndroidManifest(
              meta: meta,
              attrs: attrs,
              version_code: '${app.version_code}',
              version_name: app.version_name)
          .visit(doc);

      await file.writeAsString(update.toString());

      final propertiesFile = source + '/app/src/main/assets/config.properties';

      /// 修改properties配置
      if (File(propertiesFile).existsSync()) {
        File(propertiesFile).createSync(recursive: true);
      }

      for (var key in (model.params.app_config??{}).keys) {
        ProcessResult find =
            await shell.run('cat $propertiesFile | grep ^$key=');
        if (find.exitCode == 0) {
          await shell.run(
              'sed -i /^$key=/c$key=${model.params.app_config[key]} $propertiesFile');
        } else {
          await shell.run(
              'echo "$key=${model.params.app_config[key]}" >> $propertiesFile');
        }
      }
    } else {
      throw '$source 中未发现AndroidManifest.xml文件';
    }
  }

  void changeRes(BuildModel model, String path, String source) async {
    String appIcon = '$path/appicon.png';

    if (model.params.app_info.app_icon.isNotEmpty) {
      await Utils.download(model.params.app_info.app_icon, appIcon);
      CreateIcon.create(appIcon, '${source}/app/src/main/res');
    }
  }

  @override
  String getName() {
    return 'mdm_4';
  }

  String getTmpSrc(source) {
    return '${source}/.gradle/project';
  }

  void prepare(BuildModel model, String source) async {
    /// 下载svn代码
    var tmpSrc = getTmpSrc(source);

    Directory dir = Directory(tmpSrc);
    if (dir.existsSync()) {
      dir.deleteSync();
    }
    dir.createSync(recursive: true);

    await Utils.svnCheckout(
        url: model.params.app_info.source_url,
        path: tmpSrc,
        version: model.params.app_info.svn_version);

    Shell shell = Shell(workingDirectory: source);

    String command = 'copySrc.sh $tmpSrc $source';
    Utils.log('start run copySrc.sh in $source');
    var result = await shell.run('sh', command.split(' '));

    Utils.log(
        'copySrc in $source done,  code = ${result.exitCode}, ${result.stderr}');
    if (result.exitCode != 0) {
      throw 'copySrc error: ${result.exitCode}';
    }
  }

  void preSource(BuildModel model, String appPath) async {
    await Utils.clone(
        url: 'ssh://git@android.justsafe.com:8442/sunmh/mdm_build.git',
        path: appPath,
        branch: getName(),
        name: sourceName);
  }

  Future<void> realBuild(BuildModel model, String source) async {
    var logPath = Utils.logPath(model.build_id);

    Shell2 shell = Shell2(workDir: source);
    Utils.log('-----------------${model.build_id} 开始打包---------------------');
    ProcessResult result =
        await shell.run('chmod a+x gradlew && ./gradlew clean > $logPath');
    result =
        await shell.run('./gradlew assembleRelease --no-daemon >> $logPath');
    Utils.log('-----------------${model.build_id} 打包结束---------------------');

    if (result.exitCode != 0) {
      Utils.log(result.stderr);
      throw '编译失败, ${result.stderr}';
    }
  }

  void changeBuildGradle(BuildModel model, String source) async {
    Shell2 shell = Shell2(env: {'LANGUAGE': 'en_us'});

    String buildGradlePath = source + '/app/build.gradle';
    final file = File(buildGradlePath);
    if (file.existsSync()) {
      /// 删除versionCode
      await shell.run("sed -i -e '/versionCode */d' $buildGradlePath");

      /// 删除versionName
      await shell.run("sed -i -e '/versionName */d' $buildGradlePath");
    }
  }
}
