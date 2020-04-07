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
      var channel = model.params.version.channel;
      if (channel.isNotEmpty) {
        releasePackage =
            '$source/app/build/outputs/apk/${channel}/release/app-${channel}-release.apk';
      } else {
        releasePackage =
            '$source/app/build/outputs/apk/release/app-release.apk';
      }
      if (!File(releasePackage).existsSync()) {
        throw 'apk 包不见了';
      }
    }

    var shell = Shell2(workDir: source);

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
    var appPath = Utils.appPath(model.build_id);
    var source = '$appPath/$sourceName';

    void b() async {
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

      Utils.mail(model: model, mail: model.params.email);
    }

    runZoned(() {
      b();
    }, onError: (e, stacks) async {
      Utils.log(e);
      print(stacks);
      model.status = BuildStatus.newFailed(e.toString());
      await DBManager.save(Constant.tableBuild,
          id: propBuildId, data: model.toJson());
      Utils.mail(model: model, mail: model.params.email);
    });
  }

  void changeConfig(BuildModel model, String source) async {
    var tmpSrc = getTmpSrc(source);
    var shell = Shell2(env: {'LANGUAGE': 'en_us'});

    var app = model.params;
    var manifestFilePath = source + '/app/src/main/AndroidManifest.xml';
    final file = File(manifestFilePath);
    if (file.existsSync()) {
      var meta = <String, String>{};

      meta.addAll(app.configs.baseConfig.meta);

      if (Directory(tmpSrc).existsSync()) {
        var svn_version = model.params.version.revision;
        if (svn_version == null) {
          var result = await shell.run(
              "svn info | awk '\$3==\"Rev:\" {print \$4}'", tmpSrc);
          svn_version = result.stdout.toString().trim();
        }
        Utils.log('svn_version = $svn_version');
        meta['svn-version'] = '$svn_version';
      } else {
        if (Directory(source + '/.git').existsSync()) {
          var result = await shell.run('git rev-parse HEAD', source);

          var git_version = result.stdout.toString().trim();

          Utils.log('git_version = $git_version');
          meta['git-version'] = git_version;
        }
      }

      var attrs = <String, String>{};
      var baseConfig = app.configs.baseConfig;

      if (baseConfig.appName.isNotEmpty) {
        attrs['android:label'] = baseConfig.appName;
      }

      if (baseConfig.appIcon.isNotEmpty) {
        attrs['android:icon'] = '@drawable/auto_build_icon';
      }

      var doc = parse(await file.readAsString());

      var update = UpdateAndroidManifest(
              meta: meta,
              attrs: attrs,
              version_code: '${app.version.versionCode}',
              version_name: app.version.versionName)
          .visit(doc);

      await file.writeAsString(update.toString());

      final propertiesFile = source + '/app/src/main/assets/config.properties';

      /// 修改properties配置

      for (var key in (app.configs.appConfig ?? {}).keys) {
        if (!File(propertiesFile).existsSync()) {
          File(propertiesFile).createSync(recursive: true);
        }
        ProcessResult find =
            await shell.run('cat $propertiesFile | grep ^$key=');
        if (find.exitCode == 0) {
          await shell.run(
              'sed -i /^$key=/c$key=${app.configs.appConfig[key]} $propertiesFile');
        } else {
          await shell.run(
              'echo "$key=${app.configs.appConfig[key]}" >> $propertiesFile');
        }
      }
    } else {
      throw '$source 中未发现AndroidManifest.xml文件';
    }
  }

  void changeRes(BuildModel model, String path, String source) async {
    var appIcon = '$path/appicon.png';

    if (model.params.configs.baseConfig.appIcon.isNotEmpty) {
      await Utils.download(model.params.configs.baseConfig.appIcon, appIcon);
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

    var dir = Directory(tmpSrc);
    if (dir.existsSync()) {
      dir.deleteSync();
    }
    dir.createSync(recursive: true);

    await Utils.svnCheckout(
        url: model.params.version.sourceUrl,
        path: tmpSrc,
        version: model.params.version.revision);

    var shell = Shell(workingDirectory: source);

    var command = 'copySrc.sh $tmpSrc $source';
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

    var shell = Shell2(workDir: source);
    Utils.log('-----------------${model.build_id} 开始打包---------------------');
    ProcessResult result =
        await shell.run('chmod a+x gradlew && ./gradlew clean > $logPath');

    var channel = model.params.version.channel;
    if (channel.isNotEmpty) {
      var command =
          './gradlew assemble${channel[0].toUpperCase()}${channel.substring(1)}Release --no-daemon >> $logPath';
      result = await shell.run(command);
    } else {
      result =
          await shell.run('./gradlew assembleRelease --no-daemon >> $logPath');
    }

    Utils.log('-----------------${model.build_id} 打包结束---------------------');

    if (result.exitCode != 0) {
      Utils.log(result.stderr);
      throw '编译失败, ${result.stderr}';
    }
  }

  void changeBuildGradle(BuildModel model, String source) async {
    var shell = Shell2(env: {'LANGUAGE': 'en_us'});

    var buildGradlePath = source + '/app/build.gradle';
    final file = File(buildGradlePath);
    if (file.existsSync()) {
      /// 删除versionCode
      if (model.params.version.versionCode != null) {
        await shell.run("sed -i -e '/versionCode .*/d' $buildGradlePath");
      }

      /// 删除versionName
      if (model.params.version.versionName != null) {
        await shell.run("sed -i -e '/versionName .*/d' $buildGradlePath");
      }
    }
  }
}
