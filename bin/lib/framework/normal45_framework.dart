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
  }

  @override
  String getName() {
    return 'normal_4.5';
  }
}
