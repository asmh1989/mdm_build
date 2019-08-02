import '../model/build_model.dart';
import '../params/build_params.dart';
import '../utils.dart';
import 'mdm4_framework.dart';

class NormalFramework extends MDM4Framework {
  @override
  String getName() {
    return 'normal';
  }

  @override
  void prepare(BuildModel model, String source) async {
    Version version = model.params.version;
    var srcUrl = version.sourceUrl;

    if (srcUrl != null && (srcUrl.startsWith('ssh://') || "git" == version.scm)) {
      await Utils.clone(
          url: srcUrl, name: source, branch: version.branch, commitId: version.revision);
    } else {
      /// 下载svn代码
      await Utils.svnCheckout(
          url: version.sourceUrl,
          path: source,
          version: version.revision);
    }
  }

  @override
  void preSource(BuildModel model, String appPath) {}
}
