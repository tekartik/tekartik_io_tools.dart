library tekartik_io_tools.hg_utils;

import 'dart:async';
import 'dart:io';

import 'package:tekartik_io_tools/process_utils.dart';
import 'package:tekartik_io_tools/src/scpath.dart';
import 'package:path/path.dart';

bool _DEBUG = false;

class HgStatusResult {
  final RunResult runResult;
  HgStatusResult(this.runResult);
  bool nothingToCommit = false;
  //bool branchIsAhead = false;
}

class HgOutgoingResult {
  final RunResult runResult;
  HgOutgoingResult(this.runResult);
  bool branchIsAhead = false;
}

class HgPath {
  String _path;
  String get path => _path;
  HgPath(this._path);
  HgPath._();

  Future<RunResult> _run(List<String> args, {bool dryRun}) async {
    if (dryRun == true) {
      stdout.writeln("hg ${args.join(' ')} [$path]");
      return new RunResult();
    } else {
      return hgRun(args, workingDirectory: path);
    }
  }

  Future<HgStatusResult> status({bool printResultIfChanges}) {
    return _run(['status']).then((RunResult result) {
      HgStatusResult statusResult = new HgStatusResult(result);

      //bool showResult = true;
      if (result.exitCode == 0) {
        if (result.out.isEmpty) {
          statusResult.nothingToCommit = true;
        }
        /*
        List<String> lines = result.out.split("\n");

        lines.forEach((String line) {
          // Linux /Win?/Mac?
          if (line.startsWith('nothing to commit')) {
            statusResult.nothingToCommit = true;
          }
          if (line.startsWith('Your branch is ahead of')) {
            statusResult.branchIsAhead = true;
          }
        });
        */
      }
      if (!statusResult.nothingToCommit && (printResultIfChanges == true)) {
        _displayResult(result);
      }

      return statusResult;
    });
  }

  Future<HgOutgoingResult> outgoing({bool printResultIfChanges}) {
    return _run(['outgoing']).then((RunResult result) {
      HgOutgoingResult outgoingResult = new HgOutgoingResult(result);

      bool showResult = true;

      switch (result.exitCode) {
        case 0:
        case 1:
          {
            List<String> lines = result.out.split("\n");
            //print(lines.last);
            if (lines.last.startsWith('no changes found') ||
                lines.last.startsWith('aucun changement')) {
              outgoingResult.branchIsAhead = false;
            } else {
              outgoingResult.branchIsAhead = true;
            }
          }
          if (outgoingResult.branchIsAhead) {
            showResult = true;
          } else {
            showResult = false;
          }
      }

      if (showResult && (printResultIfChanges == true)) {
        _displayResult(result);
      }

      return outgoingResult;
    });
  }

  Future<RunResult> pull({bool update: true, bool dryRun}) {
    List<String> args = ['pull'];
    if (update == true) {
      args.add('-u');
    }
    return _run(args, dryRun: dryRun);
  }

  Future<RunResult> add({String pathspec}) {
    List<String> args = ['add', pathspec];
    return _run(args);
  }

  Future<RunResult> commit(String message, {bool all}) {
    List<String> args = ['commit'];
    if (all == true) {
      args.add("--all");
    }
    args.addAll(['-m', message]);
    return _run(args);
  }

  ///
  /// branch can be a commit/revision number
  Future<RunResult> checkout({String commit}) {
    return _run(['checkout', commit]);
  }

  void _displayResult(RunResult result) {
    print("-------------------------------");
    print("Hg project ${_path}");
    print(
        "exitCode ${result.exitCode} ${result.executable} ${result.arguments} ${result.workingDirectory}");
    print("-------------------------------");
    if (result.err.length > 0) {
      print("${result.out}");
      print("ERROR: ${result.err}");
    } else {
      print("${result.out}");
    }
  }
}

class HgProject extends HgPath {
  String src;
  HgProject(this.src, {String path, String rootFolder}) : super._() {
    var parts = scUriToPathParts(src);

    _path = joinAll(parts);

    if (_path == null) {
      throw new Exception(
          'null path only allowed for https://github.com/xxxuser/xxxproject src');
    }
    if (rootFolder != null) {
      _path = absolute(join(rootFolder, path));
    } else {
      _path = absolute(_path);
    }
  }

  Future clone({bool connectIo: false}) {
    List<String> args = ['clone'];
    args.addAll([src, path]);
    return hgRun(args, connectIo: connectIo);
  }

  Future pullOrClone() {
    // TODO: check the origin branch
    if (new File(join(path, '.hg', 'hgrc')).existsSync()) {
      return pull();
    } else {
      return clone();
    }
  }
}

Future<bool> get isHgSupported async {
  try {
    await hgRun(['--version']);
    return true;
  } catch (e) {
    return false;
  }
}

Future<RunResult> hgRun(List<String> args,
    {String workingDirectory, bool connectIo: false}) {
  if (_DEBUG) {
    print('running hg ${args}');
  }
  return run('hg', args,
      workingDirectory: workingDirectory, connectIo: connectIo).catchError((e) {
    // Caught ProcessException: No such file or directory
    if (_DEBUG) {
      print('exception: ${e}');
    }

    if (e is ProcessException) {
      print("${e.executable} ${e.arguments}");
      print(e.message);
      print(e.errorCode);

      if (e.message.contains("No such file or directory") &&
          (e.errorCode == 2)) {
        print('HG ERROR: make sure you have hg installed in your path');
      }
    }
    throw e;
  }).then((RunResult result) {
    if (_DEBUG) {
      print('result: ${result}');
    }
    return result;
  });
}

Future<bool> isHgRepository(String uri) async {
  RunResult runResult = await hgRun(['identify', uri], connectIo: false);
  // 0 is returned if found (or empty), out contains the last revision number such as 947e3404e4b7
  // 255 if an error occured
  return (runResult.exitCode == 0);
}

Future<bool> isHgTopLevelPath(String path) async {
  String dotHg = ".hg";
  String hgFile = join(path, dotHg);
  return await FileSystemEntity.isDirectory(hgFile);
}
