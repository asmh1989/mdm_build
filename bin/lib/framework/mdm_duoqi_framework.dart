import 'dart:io';

import 'package:xml/xml.dart';

import '../model/build_model.dart';
import '../shell.dart';
import '../utils.dart';
import 'mdm4_framework.dart';
import 'update_androidmanifest.dart';

class MDMDuoQiFramework extends MDM4Framework {
  @override
  String getName() {
    return 'mdm_duoqi';
  }

  @override
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
      }

      Map<String, String> attrs = Map();

      if (app.app_name != null && app.app_name.isNotEmpty) {
        attrs['android:label'] = app.app_name;
      }

      if (app.app_icon != null && app.app_icon.isNotEmpty) {
        attrs['android:icon'] = '@drawable/auto_build_icon';
      }

      attrs['android:name'] = 'com.duoqi.mdm.DuoqiApplication';

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
          version_code: '${app.version_code}',
          version_name: app.version_name)
          .visit(doc);

      await file.writeAsString(update.toString());

      final propertiesFile = source + '/app/src/main/assets/config.properties';

      /// 修改properties配置
      if (File(propertiesFile).existsSync()) {
        File(propertiesFile).createSync(recursive: true);
      }
      for (var key in model.params.app_config.keys) {
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
}
