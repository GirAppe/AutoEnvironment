![Mint compatible](https://img.shields.io/badge/🌱%20Mint-compatible-brightgreen.svg)
![SPM compatible](https://img.shields.io/badge/SPM-compatible-orange.svg?style=flat&logo=swift)
![platforms iOS | macOS | tvOS](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20tvOS-blue.svg)

# AutoEnvironment

App environment model generation from project build configurations.

In iOS it provides a feature to show app environment and version info (configurable format) on top of all views. It is effectively "watermarking" all the screenshots the testers might take with relevant version info.

## Contents

1. [Overview](#overview)
2. [Setup](#setup)
    * [Mint](#setup-mint)
    * [Swift Package Manager](#setup-spm)
3. [Usage](#usage)
4. [Version Info feature](#version-info)

<a name="overview"></a>
## Overview

Tool to automatically generate Environment enum based on Xcode project. It will allow you to easily change this:

```swift
#if DEBUG
    // debug flow
#elseif ALPHA
    // alpha flow
#elseif BETA
    // beta flow
#else
    // release flow
#endif
```

Into:

```swift
switch Environment.current {
    case .debug:
        //debug flow
    case .alpha, .beta:
        // do something for alpha and beta
    case .release:
        // only release flow
}
```

That will add a kind of compile-time safety to your code, whenever it is dependent on app environment. There would be only one file where you need to care about conditional compilation. It also allows you to unit test app, pretending to run in specific environment:

```swift
Environment.Override.current = .alpha
// test alpha
Environment.Override.current = nil
// back to default
```

It will  scan your source and generate file looking like:

```swift
enum Environment: String {
    case debug = "DEBUG"
    case release = "RELEASE"
    // other cases derived from configuration

    static var current: Environment { ... }
}
```

It will also add `OTHER_SWIFT_FLAGS` build setting for configurations:

- `-DDEBUG`for Debug
- `-DRELEASE`for Release
- `-DALPHA`for Alpha
- ... and so on

<a name="setup"></a>
## Setup

<a name="setup-mint"></a>
### Using Mint 🌱

This is a preferred way, as package was explicitly designed to work with Mint. Assuming you have installed mint already, just run:

```shell
mint install GirAppe/AutoEnvironment
```

If you don't want to link it globally, you can use `Mintfile`:

```
GirAppe/AutoEnvironment@0.1.6
```

Then you can run it:

```shell
mint run GirAppe/AutoEnvironment autoenvironment <options>
```

<a name="setup-spm"></a>
### Swift Package Manager

Add package entry to dependecies in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/GirAppe/AutoEnvironment.git", .upToNextMajor(from: "0.1.6"))
    ...
]
```

<a name="usage"></a>
## Usage

When your target name is same as xcode project filenam:

```shell
autoenvironment -p "path to your xcodeproj" -o "output directory/ filename"
```

or

```shell
autoenvironment -p "path to your xcodeproj" -o "output directory" <options>
```

Options:
* `--help`, `-h`		Show available options
* `--version`, `-v`		Print tool version
* `--path`, `-p`		Path to xcode project
* `--target`, `-t`		**Target name**. If not specified, will use Project name
* `--output`, `-o`		Output directory (with optional filename.swift)
* `--no-flags`, `-f`		Skip update build flags. If flag present, you need to update them manually
* `--default-config`, `-d`	Default configuration (e.x. Release)
* `--default-name`, `-n`	Generated Environment enum name, default: Environment
* `--silent`, `-s`		If flag present, supresses all console logs and prints

<a name="version-info"></a>
## Version Info feature

For iOS, generated enum contains additional feature to show current app version and environment info label on top of all views.

It will look something like:

// iamge

Version info for tvOS is work in progress.
