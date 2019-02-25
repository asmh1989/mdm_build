import 'mdm4_framework.dart';
import '../model/build_model.dart';
import '../utils.dart';
import 'package:shell/shell.dart';

class NormalFramework extends MDM4Framework {
  @override
  String getName() {
    return 'normal';
  }

  @override
  void prepare(BuildModel model, String source) async {
    var srcUrl = model.params.app_info.source_url;

    if (srcUrl != null && srcUrl.startsWith('ssh://')) {
      await Utils.clone(url: srcUrl, name: source);
    } else {
      /// 下载svn代码
      await Utils.svnCheckout(
          url: model.params.app_info.source_url,
          path: source,
          version: model.params.app_info.svn_version);
    }
  }

  @override
  void preSource(BuildModel model, String appPath) {}
}
