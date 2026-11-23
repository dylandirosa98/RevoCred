import 'dart:io';
import 'package:revocred_flutter/core/config/app_config.dart';

void main() {
  final config = AppConfig.fromMap(Platform.environment);
  try {
    config.validate();
  } on StateError catch (error) {
    stderr.writeln('Invalid build configuration: ${error.message}');
    exit(1);
  } catch (_) {
    stderr.writeln(
      'Invalid build configuration. Check public endpoints, auth callback, legal defines, mock flag and public Supabase key.',
    );
    exit(1);
  }
}
