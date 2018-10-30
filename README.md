# flown

A utility for cloning Flutter apps with local dependencies

`flown` will take a url and search for flutter apps. It will then recursively scan 
each app's pubspec.yaml for local dependencies anywhere
in the directory hierarchy, create a new project and install local dependencies.

[license](https://github.com/mmcc007/flown/blob/master/LICENSE).

## Usage

A simple usage example:

    flown --arch vanilla --name vanilla_project

General Usage
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

## Features and bugs

Currently restricted to using apps found on https://github.com/brianegan/flutter_architecture_examples.

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/mmcc007/flown/issues
