import 'dart:io';

import 'package:image/image.dart';

class CreateIcon {
  static Map<String, int> icons = {
    'drawable-mdpi': 64,
    'drawable-hdpi': 36,
    'drawable-xhdpi': 96,
    'drawable-xxhdpi': 144,
    'drawable-xxxhdpi': 192,
  };

  static void create(String file, String path) async {
//    Utils.log('start decode $file');
    var image = decodeImage(await File(file).readAsBytes());
//    Utils.log('decode $file done');

    for (var key in icons.keys) {
      var dir = '$path/$key';
      Directory(dir).createSync(recursive: true);
      var file = File('$dir/auto_build_icon.png');

//      Utils.log('start new ${file.path}');

      var thumbnail = copyResize(image, height: icons[key], width: icons[key]);

      await file.writeAsBytes(encodePng(thumbnail));
//      Utils.log('done new ${file.path}');

    }
  }
}
