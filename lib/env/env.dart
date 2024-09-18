// lib/env/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'OMADA_URL')
  static const String omadaUrl = _Env.omadaUrl;
  @EnviedField(varName: 'CONTROLLER_ID')
  static const String controllerId = _Env.controllerId;
  @EnviedField(varName: 'SITE_ID')
  static const String siteId = _Env.siteId;

  @EnviedField(varName: 'USERNAME')
  static const String username = _Env.username;
  @EnviedField(varName: 'PASSWORD', obfuscate: true)
  static String password = _Env.password;
}
