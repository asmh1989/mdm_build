/**
 * 打包请求参数解析
 * @author sun
 * @date 19-2-14 下午3:08
 **/

import 'package:common_utils/common_utils.dart';

class BuildParams {
  // 打包框架
  String framework;

  // 应用信息
  AppInfo app_info;

  // 应用配置
  Map<String, dynamic> app_config;

  BuildParams({
    this.framework,
    this.app_config,
    this.app_info
  });

  BuildParams.fromJson(Map<String, dynamic> json) {
    framework = json['framework'];
    app_config = json['app_config'];
    var info = json['app_info'];
    if(info != null){
      app_info = AppInfo.fromJson(info);

    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['framework'] = this.framework;
    data['app_config'] = this.app_config;
    data['app_info'] = this.app_info.toJson();
    return data;
  }

}

class AppInfo {
  // 项目名称
  String project_name;

  // 仓库地址
  String source_url;

  // svn版本号
  int svn_version;

  // 应用版本名称
  String version_name;

  // 应用版本号
  int version_code;

  // 应用名称
  String app_name;

  // 应用名称
  String app_icon;

  // meta-data参数配置
  Map<String, String> meta;


  AppInfo({
    this.project_name,
    this.source_url,
    this.svn_version,
    this.version_code,
    this.version_name,
    this.app_icon,
    this.app_name,
    this.meta,
  });

  AppInfo.fromJson(Map<String, dynamic> json) {
    project_name = json['project_name'];
    source_url = json['source_url'];

    if(!RegexUtil.isURL(source_url)){
      throw new Exception('source_url 类型错误');
    }

    svn_version = json['svn_version'];
    version_name = json['version_name'];
    version_code = json['version_code'];
    app_name = json['app_name'];
    app_icon = json['app_icon']??'';

    if(app_icon.isNotEmpty && !RegexUtil.isURL(app_icon)){
      throw new Exception('app_icon 类型错误');
    }

    meta = json['meta']?.cast<String, String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['project_name'] = this.project_name;
    data['source_url'] = this.source_url;
    data['svn_version'] = this.svn_version;
    data['version_code'] = this.version_code;
    data['version_name'] = this.version_name;
    data['app_icon'] = this.app_icon;
    data['app_name'] = this.app_name;
    data['meta'] = this.meta;
    return data;
  }
}