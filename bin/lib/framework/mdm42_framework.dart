import 'dart:io';

import 'package:xml/xml.dart';

import '../model/build_model.dart';
import '../shell.dart';
import '../utils.dart';
import 'mdm4_framework.dart';
import 'update_androidmanifest.dart';

class MDM42Framework extends MDM4Framework {
  @override
  String getName() {
    return 'mdm_4.2';
  }

  @override
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
        var svn_version = app.version.revision;
        if (svn_version == null) {
          var result = await shell.run(
              "svn info | awk '\$3==\"Rev:\" {print \$4}'", tmpSrc);
          svn_version = result.stdout.toString().trim();
        }
        Utils.log('svn_version = $svn_version');
        meta['svn-version'] = '$svn_version';
      }

      var attrs = {};

      if (app.configs.baseConfig.appName.isNotEmpty) {
        attrs['android:label'] = app.configs.baseConfig.appName;
      }

      if (app.configs.baseConfig.appIcon.isNotEmpty) {
        attrs['android:icon'] = '@drawable/auto_build_icon';
      }

      attrs['android:name'] = 'com.justsy.mdm.JustyApplication';

      var doc = parse(await file.readAsString());

      var applicationName = 'unknown';

      var applicationElement =
          doc.rootElement.findAllElements('application').toList()[0];
      for (var attr in applicationElement.attributes) {
        if (attr.name.qualified == 'android:name') {
          applicationName = attr.value;
          break;
        }
      }

      if (applicationName.startsWith('.')) {
        for (var attr in doc.rootElement.attributes) {
          if (attr.name.qualified == 'package') {
            applicationName = attr.value + applicationName;
            break;
          }
        }
      }

      meta['APPLICATION_CLASS_NAME'] = applicationName;

      var update = UpdateAndroidManifest(
              meta: meta,
              attrs: attrs,
              version_code: '${app.version.versionCode}',
              version_name: app.version.versionName)
          .visit(doc);

      await file.writeAsString(update.toString());

      final propertiesFile = source + '/app/src/main/assets/config.properties';

      /// 修改properties配置
      if (File(propertiesFile).existsSync()) {
        File(propertiesFile).createSync(recursive: true);
      }
      for (var key in app.configs.appConfig.keys) {
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
}
