import 'package:xml/xml.dart';

class UpdateAndroidManifest extends XmlTransformer {
  final Map<String, String> meta;

  final Map<String, String> attrs;

  final String version_code;
  final String version_name;

  UpdateAndroidManifest(
      {this.meta, this.attrs, this.version_name, this.version_code});

  @override
  XmlElement visitElement(XmlElement node) {
    if (node.name.qualified == 'application') {
      if (meta.isNotEmpty) {
        node.children.removeWhere((XmlNode e) {
          if (e.text == 'meta-data') {
            for (var attr in e.attributes) {
              if (meta[attr.name.qualified] != null) {
                return true;
              }
            }
          }
          return false;
        });

        for (var key in meta.keys) {
          var build = XmlElement(XmlName.fromString('meta-data'));
          build.attributes
              .add(XmlAttribute(XmlName.fromString('android:name'), key));
          build.attributes.add(
              XmlAttribute(XmlName.fromString('android:value'), meta[key]));

          node.children.add(build);
        }
      }

      if (attrs.isNotEmpty) {
        for (var key in attrs.keys) {
          node.attributes
              .removeWhere((XmlAttribute attr) => attr.name.qualified == key);
          node.attributes.add(XmlAttribute(XmlName(key), attrs[key]));
        }
      }

      return XmlElement(visit(node.name), node.attributes.map(visit),
          node.children.map(visit));
    } else if (node.name.qualified == 'manifest') {
      if (version_name != null) {
        node.attributes.removeWhere((XmlAttribute attr) =>
            attr.name.qualified == 'android:versionName');
        node.attributes
            .add(XmlAttribute(XmlName('android:versionName'), version_name));
      }

      if (version_code != null) {
        node.attributes.removeWhere((XmlAttribute attr) =>
            attr.name.qualified == 'android:versionCode');
        node.attributes
            .add(XmlAttribute(XmlName('android:versionCode'), version_code));
      }

      return XmlElement(visit(node.name), node.attributes.map(visit),
          node.children.map(visit));
    }
    return super.visitElement(node);
  }
}
