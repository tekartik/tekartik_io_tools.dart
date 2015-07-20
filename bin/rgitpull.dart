#!/usr/bin/env dart
library git_pull;

// Pull recursively

import 'dart:io';
import 'dart:async';
import 'package:path/path.dart';
import 'package:args/args.dart';
//import 'package:logging/logging.dart';
//import 'package:tekartik_common/platform_utils.dart';
//import 'package:tekartik_common/process_utils.dart';
//import 'package:tekartik_common/project_utils.dart';
import 'package:tekartik_core/log_utils.dart';
import 'package:tekartik_io_tools/git_utils.dart';

const String _HELP = 'help';
const String _LOG = 'log';

///
/// Recursively update (pull) git folders
/// 
void main(List<String> arguments) {

  setupQuickLogging();

  ArgParser parser = new ArgParser(allowTrailingOptions: true);
  parser.addFlag(_HELP, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addOption(_LOG, abbr: 'l', help: 'Log level (fine, debug, info...)');

  ArgResults _argsResult = parser.parse(arguments);

  bool help = _argsResult[_HELP];
  if (help) {
    print(parser.usage);
    return;
  }
  String logLevel = _argsResult[_LOG];
  if (logLevel != null) {
    Logger.root.level = parseLogLevel(logLevel);
    Logger.root.info('Log level ${Logger.root.level}');
  }

  // get dirs in parameters, default to current
  List<String> dirs = _argsResult.rest;
  if (dirs.isEmpty) {
    dirs = [Directory.current.path];
  }

  List<Future> futures = [];

  Future _handleDir(String dir) {
    // this is a directoru
    String dotGit = ".git";
    return (FileSystemEntity.isDirectory(dir)).then((bool isDir) {
      //print("dir $dir: ${isDir}");
      if (isDir) {
        String gitFile = join(dir, dotGit);
        return FileSystemEntity.isDirectory(gitFile).then((bool containsDotGit) {
          //print("gitFile $gitFile: ${containsDotGit}");
          if (containsDotGit) {
            gitPull(dir);
            print("git folder: ${dir}");
          } else {
            List<Future> sub = [];

            return new Directory(dir).list().listen((FileSystemEntity fse) {
              sub.add(_handleDir(fse.path));
            }).asFuture().then((_) {
              Future.wait(sub);
            });
          }
        });
      }
    });
  }
  for (String dir in dirs) {
    var _handle = _handleDir(dir);
    if (_handle is Future) {
      futures.add(_handle);
    }
  }
}

