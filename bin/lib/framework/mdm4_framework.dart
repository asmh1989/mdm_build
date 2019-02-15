import 'dart:io';
import 'dart:async';
import '../params/build_params.dart';
import 'base.dart';
import '../utils.dart';
import '../db.dart';
import '../constant.dart';
import '../model/build_model.dart';
import 'package:shell/shell.dart';

class MDM4Framework implements BaseFramework {

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

  @override
  FutureOr<void> build(BuildModel model) async{
    BuildParams params = model.params;

    String appPath = '${Utils.cachePath}/${model.build_id}';

    String appIcon = '${appPath}/appicon.png';
    String gitSrc = 'template-mdm';
    String templatePath = '/home/sun/.mdm_build/b5b84460-0b50-11e9-9947-b7139caa41b8/template-mdm';//'$appPath/$gitSrc';

    try {
//      if (params.app_info.app_icon.isNotEmpty) {
//        await Utils.download(params.app_info.app_icon, appIcon);
//      }
//
//      await Utils.clone(url: 'ssh://git@192.168.2.34:8442/sunmh/mdm_build.git',
//          path: appPath,
//          branch: getName(),
//          name: gitSrc);

//      await prepare(model, templatePath);


    } catch(e){
      model.status = BuildStatus.newFailed(e.toString());
      await DBManager.save(Constant.TABLE_BUILD, 'build_id', model.toJson());
    }
  }
}