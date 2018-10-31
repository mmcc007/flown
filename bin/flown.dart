import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import 'package:yamlicious/yamlicious.dart';
import 'package:path/path.dart' as path;

const usage = 'usage: flown [--help] --arch <arch name> --name <project name>';
const sampleUsage = 'sample usage: flown --arch vanilla --name vanilla_project';

// arg constants
const argHelp = 'help';
const argArch = 'arch';
const argName = 'name';

// pubspec constants
const pubspecYaml = 'pubspec.yaml';
const dependencies = 'dependencies';
const devDependencies = 'dev_dependencies';
const localDependencyPath = 'path';

// project constants
const projectURL = 'https://github.com/brianegan/$projectName.git';
const projectName = 'flutter_architecture_samples';
const projectsDir = 'example';

// globals
ArgParser argParser;
ArgResults argResults;

/// generate a standalone project from an example architecture
void main(List<String> arguments) {
  exitCode = 0; //presume success
  _parseCommandLineArgs(arguments);
  _validateArgs();
  _buildProject();
}

void _parseCommandLineArgs(List<String> arguments) {
  argParser = ArgParser(allowTrailingOptions: false)
    ..addOption(argArch,
        allowed: [
          'bloc_flutter',
          'built_redux',
          'firestore_redux',
          'inherited_widget',
          'mvi_flutter',
          'mvu',
          'redurx',
          'redux',
          'scoped_model',
          'simple_bloc_flutter',
          'vanilla',
        ],
        help: 'Available architectures:',
        valueHelp: 'arch name',
        allowedHelp: {
          'bloc_flutter': 'BloC pattern with Firestore backend.',
          'built_redux': 'Redux pattern with generated code.',
          'firestore_redux': 'Redux pattern with Firestore backend.',
          'inherited_widget': 'Inherited Widget pattern.',
          'mvi_flutter': 'MVI pattern with Firestore backend.',
          'mvu': 'MVU pattern.',
          'redurx': 'ReduRx pattern.',
          'redux': 'Redux pattern.',
          'scoped_model': 'Scoped Model pattern.',
          'simple_bloc_flutter': 'Simple BloC pattern with Firestore backend.',
          'vanilla': 'Standard Flutter pattern.',
        })
    ..addOption(argName,
        help: 'Name of new project.', valueHelp: 'project name')
    ..addFlag(argHelp,
        help: 'Display this help information.', negatable: false);

  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    _handleError(e.toString());
  }
}

Future _validateArgs() async {
  if (argResults.arguments.length == 0) _showUsage();
  if (argResults[argHelp]) _showUsage();
  if (argResults[argArch] == null) {
    _handleError("Missing required argument: $argArch");
  }
  if (argResults[argName] == null) {
    _handleError("Missing required argument: $argName");
  }
  if (await FileSystemEntity.isDirectory(argResults[argName])) {
    _handleError('error: directory ${argResults[argName]} already exists');
  }
}

void _handleError(String msg) {
  stderr.writeln(msg);
  _showUsage();
}

void _showUsage() {
  print('$usage');
  print('\n$sampleUsage\n');
  print(argParser.usage);
  exit(2);
}

void _buildProject() async {
  final tempDir = Directory.systemTemp.path;
  // download repo to tmp location
  if (!await FileSystemEntity.isDirectory(path.join(tempDir, projectName))) {
    print('Cloning $projectURL to $tempDir...');
    await _cmd('git', ['clone', projectURL], tempDir);
  }
  final inputDir =
      path.join(tempDir, projectName, projectsDir, argResults[argArch]);
  final outputDir = argResults[argName];

  // copy arch project
  print(
      'Copying ${argResults[argArch]} to ${argResults[argName]} with local dependencies...');
  await _copyPackage(inputDir, outputDir);

  // copy local dependencies of arch project
  _copyLocalDependencies(path.join(inputDir, pubspecYaml), inputDir, outputDir);

  // cleanup new project pubspec
  print('\nInstalling local dependencies in $outputDir...');
  _cleanupPubspec(outputDir);

  // delete downloaded url
//  await _cmd('rm', ['-rf', path.join(tempDir, projectName)]);

  print(
      '\nYour standalone ${argResults[argArch]} application is ready! To run type:');
  print('\n  \$ cd ${argResults[argName]}');
  print('  \$ flutter run\n');
}

void _copyLocalDependencies(String pubspecPath, String srcDir, String dstDir) {
  final docYaml = loadYamlDocument(File(pubspecPath).readAsStringSync());
  docYaml.contents.value.forEach((k, v) {
    if (k == dependencies || k == devDependencies) {
      v.forEach((packageName, packageInfo) {
        if (packageInfo is Map) {
          packageInfo.forEach((k, v) {
            if (k == localDependencyPath) {
              _copyPackage(path.joinAll([srcDir, path.joinAll(v.split('/'))]),
                  path.join(dstDir, packageName));
              // copy any local dependencies within this local dependency
              _copyLocalDependencies(
                  path.join(srcDir, v, pubspecYaml), srcDir, dstDir);
            }
          });
        }
      });
    }
  });
}

// set paths to dependent local packages
void _cleanupPubspec(String outputDir) {
  File file = new File(path.join(outputDir, pubspecYaml));
  final docYaml = loadYaml(file.readAsStringSync());

  // make yaml doc mutable
  final docJson = jsonDecode(jsonEncode(docYaml));

  // set path to local dependencies
  docJson.forEach((k, v) {
    if (k == dependencies || k == devDependencies) {
      v.forEach((packageName, packageInfo) {
        if (packageInfo is Map) {
          packageInfo.forEach((k, v) {
            if (k == localDependencyPath) {
              packageInfo[localDependencyPath] = packageName;
            }
          });
        }
      });
    }
  });
  // convert JSON map to string, parse as yaml, convert to yaml string and save
  file.writeAsStringSync(toYamlString(loadYaml(jsonEncode(docJson))));
}

Future _copyPackage(String srcDir, String dstDir) async {
  print('  copying to $dstDir...');
  if (Platform.isWindows) {
    await _cmd('cmd', [
      '/c',
      'echo',
      'D',
      '|',
      'xcopy',
      '$srcDir',
      '$dstDir',
      '/O',
      '/X',
      '/E',
      '/H',
      '/K',
      '>NUL'
    ]);
  } else {
    await _cmd('cp', ['-r', '$srcDir', '$dstDir']);
  }
}

Future _cmd(String cmd, List<String> arguments,
    [String workingDir = '.']) async {
  var process =
      await Process.start(cmd, arguments, workingDirectory: workingDir);
  var lineStream =
      process.stdout.transform(Utf8Decoder()).transform(LineSplitter());
  await for (var line in lineStream) {
    print(line);
  }
  var errorStream =
      process.stderr.transform(Utf8Decoder()).transform(LineSplitter());
  await for (var line in errorStream) {
    print(line);
  }
  final errorCode = await process.exitCode;
  if (errorCode != 0) {
    exit(errorCode);
  }
}
