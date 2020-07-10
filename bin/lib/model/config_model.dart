import 'dart:convert';
import 'dart:io';

import '../utils.dart';

const propAndroidHome = 'ANDROID_HOME';

const propCacheHome = 'CACHE_HOME';
const propJavaHome = 'JAVA_HOME';
const propMaxBuild = 'MAX_BUILD';
const propWhiteIps = 'WHITE_IPS';
const propZkmJar = 'ZKM_JAR';
ConfigModel envConfig;

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
    var dir = Directory('/opt/android/sdk');
    if (dir.existsSync()) {
      android_home = dir.path;
    } else {
      android_home = json[propAndroidHome] ?? '${Utils.HOME}/Android/Sdk';
    }

    dir = Directory('/usr/local/openjdk-8');

    if (dir.existsSync()) {
      java_home = dir.path;
    } else {
      java_home = json[propJavaHome] ?? '/usr/lib/jvm/java-8-openjdk-amd64';
    }

    dir = Directory('${Utils.HOME}/data/.mdm_build');
    if (dir.existsSync()) {
      cache_home = dir.path;
    } else {
      cache_home = json[propCacheHome] ?? '${Utils.HOME}/.mdm_build';
    }

    zkm_jar = json[propZkmJar] ?? '${Utils.HOME}/bin/ZKM.jar';

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

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data[propMaxBuild] = max_build;
    data[propAndroidHome] = android_home;
    data[propJavaHome] = java_home;
    data[propZkmJar] = zkm_jar;
    data[propCacheHome] = cache_home;
    data[propWhiteIps] = white_ips;
    return data;
  }

  Map<String, String> toJson2() {
    final data = <String, String>{};
    data[propMaxBuild] = '$max_build';
    data[propAndroidHome] = android_home;
    data[propJavaHome] = java_home;
    data[propZkmJar] = zkm_jar;
    data[propCacheHome] = cache_home;
    data[propWhiteIps] = json.encode(white_ips);
    return data;
  }

  void verify() async {
    if (cache_home != null && !cache_home.startsWith('/')) {
      cache_home = null;
    }

    if (android_home != null) {
      if (android_home.startsWith('/')) {
        var adb = File('$android_home/platform-tools/adb');
        if (!adb.existsSync()) {
          android_home = null;
        }
      } else {
        android_home = null;
      }
    }

    if (java_home != null) {
      if (java_home.startsWith('/')) {
        var java = File('$java_home/bin/java');
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
}
