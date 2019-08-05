import 'package:common_utils/common_utils.dart';

/// 打包请求参数解析
class BuildParams {
  Version version;
  Configs configs;

  BuildParams({this.version, this.configs});

  BuildParams.fromJson(Map<String, dynamic> json) {
    version =
        json['version'] != null ? Version.fromJson(json['version']) : null;
    configs = json['configs'] != null
        ? Configs.fromJson(json['configs'])
        : Configs.fromJson({});
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    if (this.version != null) {
      data['version'] = this.version.toJson();
    }
    if (this.configs != null) {
      data['configs'] = this.configs.toJson();
    }
    return data;
  }
}

class Version {
  String projectName;
  String moduleName;
  String scm;
  String sourceUrl;
  String branch;
  String revision;
  int versionCode;
  String versionName;

  Version(
      {this.projectName,
      this.moduleName,
      this.scm,
      this.sourceUrl,
      this.branch,
      this.revision,
      this.versionCode,
      this.versionName});

  Version.fromJson(Map<String, dynamic> json) {
    projectName = json['project_name'];
    moduleName = json['module_name'];
    scm = json['scm'] ?? '';
    scm = scm.toLowerCase();

    sourceUrl = json['source_url'];

    if (!RegexUtil.isURL(sourceUrl)) {
      throw 'source_url 类型错误';
    }

    branch = json['branch'];
    revision = json['revision'];
    versionCode = json['version_code'];
    versionName = json['version_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['project_name'] = this.projectName;
    data['module_name'] = this.moduleName;
    data['scm'] = this.scm;
    data['source_url'] = this.sourceUrl;
    data['branch'] = this.branch;
    data['revision'] = this.revision;
    data['version_code'] = this.versionCode;
    data['version_name'] = this.versionName;
    return data;
  }
}

class BaseConfig {
  String appName;
  String appIcon;

  /// meta-data参数配置
  Map<String, String> meta;

  BaseConfig({this.appName, this.appIcon, this.meta});

  BaseConfig.fromJson(Map<String, dynamic> json) {
    appName = json['app_name'] ?? '';
    appIcon = json['app_icon'] ?? '';

    if (appIcon.isNotEmpty && !RegexUtil.isURL(appIcon)) {
      throw 'app_icon 类型错误';
    }

    meta = (json['meta'] ?? {})?.cast<String, String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['app_name'] = this.appName;
    data['app_icon'] = this.appIcon;
    if (this.meta != null) {
      data['meta'] = this.meta;
    }
    return data;
  }
}

class Configs {
  /// 打包框架
  String framework;
  BaseConfig baseConfig;

  /// 应用配置
  Map<String, dynamic> appConfig;

  Configs({this.framework, this.baseConfig, this.appConfig});

  Configs.fromJson(Map<String, dynamic> json) {
    framework = json['framework'];
    baseConfig = json['base_config'] != null
        ? BaseConfig.fromJson(json['base_config'])
        : BaseConfig.fromJson({});
    appConfig = json['app_config'] ?? {};
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['framework'] = this.framework;
    if (this.baseConfig != null) {
      data['base_config'] = this.baseConfig.toJson();
    }
    if (this.appConfig != null) {
      data['app_config'] = this.appConfig;
    }
    return data;
  }
}
