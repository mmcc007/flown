import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import 'package:yamlicious/yamlicious.dart';

const usage =
    'usage: flown [--help] --arch=<arch name> --out=<project directory>';
const sampleUsage =
    'sample usage: flown --arch vanilla --out /tmp/vanilla_project';

// arg constants
const argHelp = 'help';
const argArch = 'arch';
const argOut = 'out';

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
String projectName;
String projectDir;

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
    ..addOption(argOut,
        help: 'Directory location for new standalone project.',
        valueHelp: 'dir')
    ..addFlag(argHelp,
        help: 'Display help information for create_project.', negatable: false);

  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    _handleError(e.toString());
  }
}

Future _validateArgs() async {
  if (argResults[argHelp]) _showUsage();
  if (!await FileSystemEntity.isDirectory('.git')) {
    _handleError('error: not in root of flutter_architecture_samples repo');
  }
  if (argResults[argArch] == null) {
    _handleError("Missing required argument: arch");
  }
  if (argResults[argOut] == null) {
    _handleError("Missing required argument: out");
  }
  if (await FileSystemEntity.isDirectory(argResults[argOut])) {
    _handleError('error: directory ${argResults[argOut]} already exists');
  }
  final pathComponents = argResults[argOut].split('/');
  projectName = pathComponents.removeLast();
  projectDir = pathComponents.join('/');
  if (!await FileSystemEntity.isDirectory(projectDir)) {
    _handleError('error: $projectDir is not a directory');
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

void _buildProject() {
  final inputDir = '$projects/${argResults[argArch]}';
  final outputDir = argResults[argOut];

  // create default project
  print('Creating $projectName in $projectDir. Please wait...\n');
  _cmd('flutter', ['create', '$projectName'], projectDir);

  // delete default lib and test
  _cmd('rm', ['-rf', 'lib', 'test'], outputDir);

  // copy arch project
  print(
      'Copying ${argResults[argArch]} to ${argResults[argOut]} with local dependencies...');
  _copyPackage(inputDir, outputDir);

  // copy local dependencies of arch project
  _copyLocalDependencies(
      '$projects/${argResults[argArch]}/$pubspecYaml', inputDir, outputDir);

  // cleanup new project pubspec
  print('\nInstalling local dependencies in $projectName...');
  _cleanupPubspec(outputDir);

  // todo apply android/ios fixes for specific projects
  _fixProjectBuilds(inputDir, outputDir);

  // get packages in new project to confirm dependencies installed
  _cmd('flutter', ['packages', 'get'], outputDir);

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

void _copyPackage(String srcDir, String dstDir) async {
  print('  copying to $dstDir...');
  _cmd('mkdir', ['-p', dstDir]);
  _cmd('cp', ['-r', '$srcDir/lib', '$dstDir']);
  _cmd('cp', ['$srcDir/$pubspecYaml', dstDir]);
  // copy additional directories if available
  if (await FileSystemEntity.isDirectory('$srcDir/test')) {
    _cmd('cp', ['-r', '$srcDir/test', '$dstDir']);
  }
  if (await FileSystemEntity.isDirectory('$srcDir/test_driver')) {
    _cmd('cp', ['-r', '$srcDir/test_driver', '$dstDir']);
  }
}

void _cmd(String cmd, List<String> arguments, [String workingDir = '.']) {
  final result = Process.runSync(cmd, arguments, workingDirectory: workingDir);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr.write(
        '\nError: command failed: \'$cmd $arguments\' with exit code \'$exitCode\'\n');
    exit(result.exitCode);
  }
}

// set paths to dependent local packages
void _cleanupPubspec(String outputDir) {
  File file = new File('$outputDir/$pubspecYaml');
  final docYaml = loadYaml(file.readAsStringSync());

  // make mutable
  final docJson = jsonDecode(jsonEncode(docYaml));
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

// android/ios project specific fixes
void _fixProjectBuilds(String src, String dst) {
  switch (argResults[argArch]) {
    case 'simple_bloc_flutter':
      print('\nApplying build configuration for $projectName...');
      _cmd('cp', [
        '$src/android/build.gradle',
        '$dst/android/build.gradle',
      ]);
      _cmd('cp', [
        '$src/android/app/build.gradle',
        '$dst/android/app/build.gradle',
      ]);
      _cmd('cp', [
        '$src/android/app/google-services.json',
        '$dst/android/app/google-services.json'
      ]);

      break;
  }
}
