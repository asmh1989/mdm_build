import 'dart:io';
import 'dart:async';
import '../params/build_params.dart';
import 'base.dart';
import '../utils.dart';
import '../db.dart';
import '../constant.dart';
import '../model/build_model.dart';

class MDM4Framework implements BaseFramework {

  @override
  String getName() {
    return 'mdm_4';
  }

  @override
  FutureOr<void> build(BuildModel model) async{
    BuildParams params = model.params;

    String appPath = '${Utils.cachePath}/${model.build_id}';

    String appIcon = '${appPath}/appicon.png';
    String gitSrc = 'template-mdm';
    String templatePath = '$appPath/$gitSrc';

    try {
      if (params.app_info.app_icon.isNotEmpty) {
        await Utils.download(params.app_info.app_icon, appIcon);
      }

      await Utils.clone(url: 'ssh://git@192.168.2.34:8442/sunmh/mdm_build.git',
          path: appPath,
          branch: getName(),
          name: gitSrc);


    } catch(e){
      model.status = BuildStatus.newFailed(e.toString());
      await DBManager.save(Constant.TABLE_BUILD, 'build_id', model.toJson());
    }
  }
}