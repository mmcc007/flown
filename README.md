[![pub package](https://img.shields.io/pub/v/flown.svg)](https://pub.dartlang.org/packages/flown)

# flown

A utility for cloning Flutter apps with local dependencies

`flown` will scan for and present available Flutter apps at a url. After the user 
selects an app, it will then recursively scan the app's pubspec.yaml for any local dependencies, 
copy the app and local dependencies to a new directory and install local dependencies.

[LICENSE](https://github.com/mmcc007/flown/blob/master/LICENSE)

## Usage

A sample usage:

    flown --arch vanilla --name vanilla_project

General usage
```
$ flown --help
usage: flown [--help] --arch <arch name> --name <project name>

sample usage: flown --arch vanilla --name vanilla_project

--arch=<arch name>             Available architectures:

      [bloc_flutter]           BloC pattern with Firestore backend.
      [built_redux]            Redux pattern with generated code.
      [firestore_redux]        Redux pattern with Firestore backend.
      [inherited_widget]       Inherited Widget pattern.
      [mvi_flutter]            MVI pattern with Firestore backend.
      [mvu]                    MVU pattern.
      [redurx]                 ReduRx pattern.
      [redux]                  Redux pattern.
      [scoped_model]           Scoped Model pattern.
      [simple_bloc_flutter]    Simple BloC pattern with Firestore backend.
      [vanilla]                Standard Flutter pattern.

--name=<project name>          Name of new project.
--help                         Display this help information.
```
 
## Installation

    pub global activate flown

Dependencies
[Flutter SDK](https://flutter.io/get-started/install/) should be installed. 
At minimum requires [Dart](https://www.dartlang.org/install). 
Also depends on git.

## Features and bugs

Currently restricted to using Flutter apps found on https://github.com/brianegan/flutter_architecture_examples.

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/mmcc007/flown/issues
