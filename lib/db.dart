/**
 *
 * @author sun
 * @date 19-2-14 下午5:32
 **/

import 'package:mongo_dart/mongo_dart.dart' ;

class DBManager {

  final String TABLE_APP = 'app';
  final String TABLE_BUILD = 'buildid';
  final String TABLE_RELEASE = 'release';

  static Db _db;

  static void contect() async{
    if(_db == null || _db.state != State.OPEN ){
      _db = new Db('mongodb://127.0.0.1:27017/builder');
      Stopwatch stopwatch = new Stopwatch()..start();

      await _db.open();
    }
  }

}