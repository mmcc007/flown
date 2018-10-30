import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import 'package:yamlicious/yamlicious.dart';

const usage = 'usage: flown [--help] --arch <arch name> --name <project name>';
const sampleUsage = 'sample usage: flown --arch vanilla --name vanilla_project';

// arg constants
const argHelp = 'help';
const argArch = 'arch';
const argOut = 'name';

// pubspec constants
const pubspecYaml = 'pubspec.yaml';
const dependencies = 'dependencies';
const devDependencies = 'dev_dependencies';
const localDependencyPath = 'path';

// project constants
const projects = 'example';

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
    ..addOption(argOut, help: 'Name of new project.', valueHelp: 'project name')
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
    _handleError("Missing required argument: arch");
  }
  if (argResults[argOut] == null) {
    _handleError("Missing required argument: out");
  }
  if (await FileSystemEntity.isDirectory(argResults[argOut])) {
    _handleError('error: directory ${argResults[argOut]} already exists');
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
  // download repo to tmp location
  if (!await FileSystemEntity.isDirectory(
      '/tmp/flutter_architecture_samples')) {
    print(
        'Cloning https://github.com/brianegan/flutter_architecture_samples.git to /tmp...');
    await _cmd(
        'git',
        [
          'clone',
          'https://github.com/brianegan/flutter_architecture_samples.git'
        ],
        '/tmp');
  }
  final inputDir =
      '/tmp/flutter_architecture_samples/$projects/${argResults[argArch]}';
  final outputDir = argResults[argOut];

  // copy arch project
  print(
      'Copying ${argResults[argArch]} to ${argResults[argOut]} with local dependencies...');
  await _copyPackage(inputDir, outputDir);

  // copy local dependencies of arch project
  _copyLocalDependencies(
      '/tmp/flutter_architecture_samples/$projects/${argResults[argArch]}/$pubspecYaml',
      inputDir,
      outputDir);

  // cleanup new project pubspec
  print('\nInstalling local dependencies in $outputDir...');
  _cleanupPubspec(outputDir);

  // get packages in new project to confirm dependencies installed
//  await _cmd('flutter', ['packages', 'get'], outputDir);

  print(
      '\nYour standalone ${argResults[argArch]} application is ready! To run type:');
  print('\n  \$ cd ${argResults[argOut]}');
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
              _copyPackage('$srcDir/$v', '$dstDir/$packageName');
              // copy any local dependencies within this local dependency
              _copyLocalDependencies('$srcDir/$v/$pubspecYaml', srcDir, dstDir);
            }
          });
        }
      });
    }
  });
}

Future _copyPackage(String srcDir, String dstDir) async {
  print('  copying to $dstDir...');
  await _cmd('cp', ['-r', '$srcDir', '$dstDir']);
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

// set paths to dependent local packages
void _cleanupPubspec(String outputDir) {
  File file = new File('$outputDir/$pubspecYaml');
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