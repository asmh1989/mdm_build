import 'dart:io';
import 'package:image/image.dart';
import '../utils.dart';

class CreateIcon{

  static Map<String, int> icons = {
    'drawable-mdpi': 64,
    'drawable-hdpi': 36,
    'drawable-xhdpi': 96,
    'drawable-xxhdpi': 144,
    'drawable-xxxhdpi': 192,
  };

  static void create(String file, String path) async {
//    Utils.log('start decode $file');
    Image image = decodeImage(await new File(file).readAsBytes());
//    Utils.log('decode $file done');

    for(String  key in icons.keys){
      String dir ='$path/$key';
      Directory(dir).createSync(recursive: true);
      File file =  new File('$dir/auto_build_icon.png');

//      Utils.log('start new ${file.path}');

      Image thumbnail = copyResize(image, icons[key]);

      await file.writeAsBytes(encodePng(thumbnail));
//      Utils.log('done new ${file.path}');

    }
  }


}