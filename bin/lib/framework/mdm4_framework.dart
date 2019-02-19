import 'dart:io';
import 'dart:async';
import 'base.dart';
import '../utils.dart';
import '../db.dart';
import '../constant.dart';
import '../model/build_model.dart';
import 'package:shell/shell.dart';
import 'create_icon.dart';
import 'package:xml/xml.dart';
import '../shell.dart';

class UpdateAndroidManifest extends XmlTransformer {

  Map<String, String> meta;

  Map<String, String> attrs;

  String version_code;
  String version_name;

  UpdateAndroidManifest({this.meta, this.attrs, this.version_name, this.version_code});

  @override
  XmlElement visitElement(XmlElement node) {
    if (node.name.qualified == 'application') {

      if(meta.isNotEmpty) {
        node.children.removeWhere((XmlNode e) {
          if (e.text == 'meta-data') {
            for (var attr in e.attributes) {
              if (meta[attr.name.qualified] != null){
                return true;
              }
            }
          }
          return false;
        });

        for(var key in meta.keys){
          var build = new XmlElement(XmlName.fromString('meta-data'));
          build.attributes.add(new XmlAttribute(XmlName.fromString('android:name'), key));
          build.attributes.add(new XmlAttribute(XmlName.fromString('android:value'), meta[key]));

          node.children.add(build);
        }

      }

      if(attrs.isNotEmpty){
        for(var key in attrs.keys){
          node.attributes.removeWhere((XmlAttribute attr) =>
          attr.name.qualified == key);
          node.attributes.add(
              new XmlAttribute(XmlName(key), attrs[key]));
        }

      }

      return new XmlElement(
          visit(node.name), node.attributes.map(visit),
          node.children.map(visit));
    } else if (node.name.qualified == 'manifest') {
      if (version_name != null) {
        node.attributes.removeWhere((XmlAttribute attr) =>
        attr.name.qualified == 'android:versionName');
        node.attributes.add(
            new XmlAttribute(XmlName('android:versionName'), version_name));
      }

      if (version_code != null) {
        node.attributes.removeWhere((XmlAttribute attr) =>
        attr.name.qualified == 'android:versionCode');
        node.attributes.add(
            new XmlAttribute(XmlName('android:versionCode'), version_code));
      }

      return new XmlElement(visit(node.name), node.attributes.map(visit),
          node.children.map(visit));
    }
    return super.visitElement(node);
  }
}

class MDM4Framework implements BaseFramework {

  String gitSrc = 'template-mdm';

  @override
  String getName() {
    return 'mdm_4';
  }

  String getTmpSrc(source) {
    return '${source}/.gradle/project';
  }

  void preSource(BuildModel model, String appPath) async {
    await Utils.clone(url: 'ssh://git@192.168.2.34:8442/sunmh/mdm_build.git',
        path: appPath,
        branch: getName(),
        name: gitSrc);
  }

  void prepare(BuildModel model, String source) async {
    /// 下载svn代码
    var tmpSrc = getTmpSrc(source);

    Directory dir = new Directory(tmpSrc);
    if(dir.existsSync()){
      dir.deleteSync();
    }
    dir.createSync(recursive: true);

    await Utils.svnCheckout(url: model.params.app_info.source_url, path: tmpSrc, version: model.params.app_info.svn_version);

    Shell shell = new Shell(workingDirectory: source);

    String command = 'copySrc.sh $tmpSrc $source';
    Utils.log('start run copySrc.sh in $source');
    var result = await shell.run('sh', command.split(' '));

    Utils.log('copySrc in $source done,  code = ${result.exitCode}, ${result.stderr}');
    if(result.exitCode != 0){
      throw new Exception('copySrc error: ${result.exitCode}');
    }
  }

  void changeRes(BuildModel model, String path, String source) async {
    String appIcon = '$path/appicon.png';


    if (model.params.app_info.app_icon.isNotEmpty) {
      await Utils.download(model.params.app_info.app_icon, appIcon);
      CreateIcon.create(appIcon, '${source}/app/src/main/res');
    }
  }

  void changeConfig(BuildModel model, String source) async {
    var tmpSrc = getTmpSrc(source);
    Shell2 shell = new Shell2(env: {'LANGUAGE':'en_us'});

    var app = model.params.app_info;
    String manifestFilePath = source + '/app/src/main/AndroidManifest.xml';
    final file = new File(manifestFilePath);
    if(file.existsSync()){
      var svn_version = model.params.app_info.svn_version;
      if(svn_version == null){
        var result = await shell.run("svn info | awk '\$3==\"Rev:\" {print \$4}'", tmpSrc);
        svn_version =  int.parse(result.stdout.toString().trim());
      }

      Utils.log('svn_version = $svn_version');

      var meta = app.meta;
      Map<String, String> attrs = new Map();

      if(app.app_name != null && app.app_name.isNotEmpty){
        attrs['android:label'] = app.app_name;
      }

      if(app.app_icon!= null && app.app_icon.isNotEmpty){
        attrs['android:icon'] = '@drawable/auto_build_icon';
      }

      meta['svn-version'] = '$svn_version';

      var doc =  parse(await file.readAsString());

      var update = new UpdateAndroidManifest(meta: meta, attrs: attrs, version_code: '${app.version_code}', version_name: app.version_name).visit(doc);

      await file.writeAsString(update.toString());

      final propertiesFile = source + '/app/src/main/assets/config.properties';

      /// 修改properties配置
      if(new File(propertiesFile).existsSync()){
        for(var key in model.params.app_config.keys){
          ProcessResult find = await shell.run('cat $propertiesFile | grep ^$key=');
          if(find.exitCode == 0){
            await shell.run('sed -i /^$key=/c$key=${model.params.app_config[key]} $propertiesFile');
          } else {
            await shell.run('echo "$key=${model.params.app_config[key]}" >> $propertiesFile');
          }
        }
      } else {
        Utils.log('$propertiesFile is not exist');
      }

    } else {
      throw new Exception('$source 中未发现AndroidManifest.xml文件');
    }


  }

  Future<void> realBuild(BuildModel model, String source) async {
    var logPath = Utils.logPath(model.build_id);


    Shell2 shell = new Shell2(workDir: source);
    Utils.log('-----------------${model.build_id} 开始打包---------------------');
    ProcessResult result = await shell.run('chmod a+x gradlew && ./gradlew clean > $logPath');
    result = await shell.run('./gradlew assembleRelease --no-daemon >> $logPath');
    Utils.log('-----------------${model.build_id} 打包结束---------------------');

    if (result.exitCode != 0) {
      throw new Exception('编译失败, ${result.stderr}');
    }

  }

  void afterBuild(BuildModel model, String source) async {
    var savePath = Utils.packagePath(model.build_id);
    var releasePackage = '$source/app/build/outputs/apk/app-release.apk';
    if(!File(releasePackage).existsSync()){
      releasePackage = '$source/app/build/outputs/apk/release/app-release.apk';
      if(!File(releasePackage).existsSync()){
        throw new Exception('apk 包不见了');
      }
    }

    Shell2 shell = new Shell2(workDir: source);

    if(File('$source/resign.sh').existsSync()){
      Utils.log('发现重新签名脚步...');
      var result = await shell.run('sh $source/resign.sh');
      if(result.exitCode != 0) {
        throw new Exception('重新签名失败');
      }
    }

    await shell.run('cp  $releasePackage $savePath');

  }

  @override
  FutureOr<void> build(BuildModel model) async{
    String appPath = Utils.appPath(model.build_id);
    String source = '$appPath/$gitSrc';

    b() async {

      /// mdm_4 需要在as工程下进行编译, 所以需要先下载模板
      await preSource(model, appPath);

      /// 准备工作, 下载实际的svn代码, 并把需要的代码合并到模板工程中
      await prepare(model, source);

      ///  修改app icon
      await changeRes(model, appPath, source);

      /// 修改配置
      await changeConfig(model, source);

      /// 开始编译
      await realBuild(model, source);

      /// 编译后处理
      await afterBuild(model, source);

      model.status = BuildStatus.SUCCESS;
      await DBManager.save(Constant.TABLE_BUILD, id: PROP_BUILD_ID, data: model.toJson());
      Utils.log('${model.build_id}, 打包结束.....');
    }

    runZoned((){
      b();
    }, onError: (e, stacks) async {
      Utils.log(e);
      print(stacks);
      model.status = BuildStatus.newFailed(e.toString());
      await DBManager.save(Constant.TABLE_BUILD, id: PROP_BUILD_ID, data: model.toJson());
    });
  }
}