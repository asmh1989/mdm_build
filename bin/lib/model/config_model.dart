import 'dart:io';
import 'dart:convert';
import '../utils.dart';

ConfigModel envConfig;

const propMaxBuild = 'MAX_BUILD';
const propAndroidHome = 'ANDROID_HOME';
const propJavaHome = 'JAVA_HOME';
const propZkmJar = 'ZKM_JAR';
const propCacheHome = 'CACHE_HOME';
const propWhiteIps = 'WHITE_IPS';

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
    max_build = json[propMaxBuild] ?? 3;
    android_home = json[propAndroidHome] ?? '${Utils.HOME}/Android/Sdk';
    java_home = json[propJavaHome] ?? '/usr/lib/jvm/java-8-openjdk-amd64';
    zkm_jar = json[propZkmJar] ?? '${Utils.HOME}/bin/ZKM.jar';
    cache_home = json[propCacheHome] ?? '${Utils.HOME}/.mdm_build';
    white_ips = json[propWhiteIps] ?? [];
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
        if (!white_ips.contains(key)) {
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
    data[propMaxBuild] = max_build;
    data[propAndroidHome] = android_home;
    data[propJavaHome] = java_home;
    data[propZkmJar] = zkm_jar;
    data[propCacheHome] = cache_home;
    data[propWhiteIps] = white_ips;
    return data;
  }

  Map<String, String> toJson2() {
    final Map<String, String> data = new Map<String, String>();
    data[propMaxBuild] = '$max_build';
    data[propAndroidHome] = android_home;
    data[propJavaHome] = java_home;
    data[propZkmJar] = zkm_jar;
    data[propCacheHome] = cache_home;
    data[propWhiteIps] = json.encode(white_ips);
    return data;
  }
}
