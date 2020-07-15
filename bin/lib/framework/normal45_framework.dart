import 'dart:io';

import '../model/build_model.dart';
import '../shell.dart';
import '../utils.dart';
import 'normal_framework.dart';

class Normal45Framework extends NormalFramework {
  @override
  void changeConfig(BuildModel model, String source) async {
    super.changeConfig(model, source);
    var url = model.params.configs.baseConfig.assets_config;
    var shell = Shell2(env: {'LANGUAGE': 'en_us'});

    if (url.isNotEmpty) {
      var zip = '$source/.test.zip';

      ProcessResult result = await shell.run('wget "$url" -O $zip');
      if (result.exitCode != 0) {
        Utils.log(result.stderr);
        throw '$url 下载出错了!!';
      }

      result = await shell.run(
          'cd $source/core_main/src/main/assets/config && rm -rf * && unzip $zip');

      if (result.exitCode != 0) {
        Utils.log(result.stderr);
        throw 'assets_config zip文件 压缩覆盖出错!!';
      }
    }

    /// 删除不必要的模块
    await shell
        .run('sed -i "s/\'\:developer_debug\',//g" $source/settings.gradle');
    await shell.run('sed -i -e "/:developer_debug/d" $source/app/build.gradle');

    /// 删除core_update 模块中的meta-data 配置
    await shell.run(
        'sed -i "/<meta-data/,/\\/>/d" $source/core_update/src/main/AndroidManifest.xml');
  }

  @override
  String getName() {
    return 'normal_4.5';
  }

  @override
  Future<void> realBuild(BuildModel model, String source) async {
    var logPath = Utils.logPath(model.build_id);

    var shell = Shell2(workDir: source);
    Utils.log('-----------------${model.build_id} 开始打包---------------------');
    ProcessResult result;

    var channel = model.params.version.channel;
    if (channel.isNotEmpty) {
      var command =
          'chmod a+x gradlew && ./gradlew assemble${channel[0].toUpperCase()}${channel.substring(1)}Release --no-daemon >> $logPath';
      result = await shell.run(command);
    } else {
      result = await shell.run(
          'chmod a+x gradlew && ./gradlew assembleRelease --no-daemon >> $logPath');
    }

    Utils.log('-----------------${model.build_id} 打包结束---------------------');

    if (result.exitCode != 0) {
      Utils.log(result.stderr);
      throw '编译失败, ${result.stderr}';
    }
  }
}
