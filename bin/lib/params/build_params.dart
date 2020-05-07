import 'package:common_utils/common_utils.dart';

/// 打包请求参数解析
class BuildParams {
  Version version;
  Configs configs;
  String email;

  BuildParams({this.version, this.configs, this.email});

  BuildParams.fromJson(Map<String, dynamic> json) {
    version =
        json['version'] != null ? Version.fromJson(json['version']) : null;
    configs = json['configs'] != null
        ? Configs.fromJson(json['configs'])
        : Configs.fromJson({});

    email = json['email'] ?? '';
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (version != null) {
      data['version'] = version.toJson();
    }
    if (configs != null) {
      data['configs'] = configs.toJson();
    }

    if (email.isNotEmpty) {
      data['email'] = email;
    }
    return data;
  }
}

class Version {
  String projectName;
  String moduleName;
  String scm;
  String sourceUrl;
  String channel;
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
      this.channel,
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
    channel = json['channel'] ?? '';
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['project_name'] = projectName;
    data['module_name'] = moduleName;
    data['scm'] = scm;
    data['source_url'] = sourceUrl;
    data['branch'] = branch;
    data['revision'] = revision;
    data['version_code'] = versionCode;
    data['version_name'] = versionName;
    if (channel.isNotEmpty) {
      data['channel'] = channel;
    }
    return data;
  }
}

class BaseConfig {
  String appName;
  String appIcon;

  /// assets/config
  String assets_config;

  /// meta-data参数配置
  Map<String, String> meta;

  BaseConfig(
      {this.appName = '',
      this.appIcon = '',
      this.meta,
      this.assets_config = ''});

  BaseConfig.fromJson(Map<String, dynamic> json) {
    appName = json['app_name'] ?? '';
    appIcon = json['app_icon'] ?? '';

    if (appIcon.isNotEmpty && !RegexUtil.isURL(appIcon)) {
      throw 'app_icon 类型错误';
    }

    meta = (json['meta'] ?? {})?.cast<String, String>();

    assets_config = json['assets_config'] ?? '';

    if (assets_config.isNotEmpty && !RegexUtil.isURL(assets_config)) {
      throw 'assets_config 类型错误';
    }
  }

  Map<String, dynamic> toJson() {
    var data = <String, dynamic>{};
    if (appName.isNotEmpty) {
      data['app_name'] = appName;
    }
    if (appIcon.isNotEmpty) {
      data['app_icon'] = appIcon;
    }
    if (meta != null && meta.isNotEmpty) {
      data['meta'] = meta;
    }

    if (assets_config.isNotEmpty) {
      data['assets_config'] = assets_config;
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
    final data = <String, dynamic>{};
    data['framework'] = framework;
    if (baseConfig != null) {
      data['base_config'] = baseConfig.toJson();
    }
    if (appConfig != null) {
      data['app_config'] = appConfig;
    }
    return data;
  }
}
