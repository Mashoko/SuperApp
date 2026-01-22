import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  static String md5Hash(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }
}
