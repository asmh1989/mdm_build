import 'dart:io';
import 'dart:convert';
import '../utils.dart';

ConfigModel env_config;

const PROP_MAX_BUILD = 'MAX_BUILD';
const PROP_ANDROID_HOME = 'ANDROID_HOME';
const PROP_JAVA_HOME = 'JAVA_HOME';
const PROP_ZKM_JAR = 'ZKM_JAR';
const PROP_CACHE_HOME = 'CACHE_HOME';

const PROP_WHITE_IPS = 'WHITE_IPS';

class ConfigModel {
  int max_build;
  String android_home;
  String java_home;
  String zkm_jar;
  String cache_home;

  List<dynamic> white_ips;

  ConfigModel(
      {this.max_build,
      this.android_home,
      this.java_home,
      this.cache_home,
      this.zkm_jar,
      this.white_ips});

  ConfigModel.fromJson(Map<String, dynamic> json) {
    max_build = json[PROP_MAX_BUILD] ?? 3;
    android_home = json[PROP_ANDROID_HOME] ?? '${Utils.HOME}/Android/Sdk';
    java_home = json[PROP_JAVA_HOME] ?? '/usr/lib/jvm/java-8-openjdk-amd64';
    zkm_jar = json[PROP_ZKM_JAR] ?? '${Utils.HOME}/bin/ZKM.jar';
    cache_home = json[PROP_CACHE_HOME] ?? '${Utils.HOME}/.mdm_build';
    white_ips = json[PROP_WHITE_IPS] ?? [];
  }

  void merge(ConfigModel update) {
    update.verify();
    if (update.max_build != null &&
        update.max_build != max_build &&
        update.max_build > 2) {
      max_build = update.max_build;
    }

    if (update.android_home != null &&
        update.android_home.isNotEmpty &&
        update.android_home != android_home) {
      android_home = update.android_home;
    }

    if (update.java_home != null &&
        update.java_home.isNotEmpty &&
        update.java_home != java_home) {
      java_home = update.java_home;
    }

    if (update.zkm_jar != null &&
        update.zkm_jar.isNotEmpty &&
        update.zkm_jar != zkm_jar) {
      zkm_jar = update.zkm_jar;
    }

    if (update.cache_home != null &&
        update.cache_home.isNotEmpty &&
        update.cache_home != cache_home) {
      cache_home = update.cache_home;
    }

    if (update.white_ips != null) {
      for (var key in update.white_ips) {
        if(!white_ips.contains(key)){
          white_ips.add(key);
        }
      }
    }
  }

  void verify() async {
    if (cache_home != null && !cache_home.startsWith('/')) {
      cache_home = null;
    }

    if (android_home != null) {
      if (android_home.startsWith('/')) {
        File adb = File('$android_home/platform-tools/adb');
        if (!adb.existsSync()) {
          android_home = null;
        }
      } else {
        android_home = null;
      }
    }

    if (java_home != null) {
      if (java_home.startsWith('/')) {
        File java = File('$java_home/bin/java');
        if (!java.existsSync()) {
          java_home = null;
        }
      } else {
        java_home = null;
      }
    }

    if (zkm_jar != null) {
      if (zkm_jar.startsWith('/')) {
        if (!File(zkm_jar).existsSync()) {
          zkm_jar = null;
        }
      } else {
        zkm_jar = null;
      }
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data[PROP_MAX_BUILD] = max_build;
    data[PROP_ANDROID_HOME] = android_home;
    data[PROP_JAVA_HOME] = java_home;
    data[PROP_ZKM_JAR] = zkm_jar;
    data[PROP_CACHE_HOME] = cache_home;
    data[PROP_WHITE_IPS] = white_ips;
    return data;
  }

  Map<String, String> toJson2() {
    final Map<String, String> data = new Map<String, String>();
    data[PROP_MAX_BUILD] = '$max_build';
    data[PROP_ANDROID_HOME] = android_home;
    data[PROP_JAVA_HOME] = java_home;
    data[PROP_ZKM_JAR] = zkm_jar;
    data[PROP_CACHE_HOME] = cache_home;
    data[PROP_WHITE_IPS] = json.encode(white_ips);
    return data;
  }
}
