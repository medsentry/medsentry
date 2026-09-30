import 'storage_interface.dart';

DatabaseStorage createDatabaseStorage() => throw UnsupportedError(
  'Cannot create database storage without dart:io or dart:js_interop.',
);
