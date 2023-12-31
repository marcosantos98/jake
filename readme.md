# Jake - CMake like tool for java

## :warning: WARNING

> This WIP tool. Beware that this probably contains bugs
> Also no documentation for now, check the `example` folder for simple documentation.
> Check JakeProject struct in `main.v` for required fields and optional fields for jakefile.json.

## Why:

Tools like gradle or maven become to slow when building simple projects because they are designed for large projects and work on a lot of different scenarios.

When using gradle to build the same code that is present in the `example` folder, without using any testing framework, I got the following results.

| Tool   | Time Fresh | Time After First Build | Modifying the Main.java |
| ------ | ---------- | ---------------------- | ---------------------- |
| Gradle | 0.860ms    | 0.750ms                | 0.830ms                |
| Jake   | 0.460ms    | 0.110ms                | 0.470ms                |

These times have been taken in the following environments:
- CPU: i7 9700k
- Java: OpenJDK 17
- OS: ArchLinux
- Project: [example/]()
- No dependencies or test framework in Gradle, only a basic application with the testing framework stripped.

The following times may be affected by the fact that `jake` is written in V which translates to C, and `Gradle` is written in Java. And we all know that C is just faster.

### Quick start:

1. Clone repo
```
git clone https://github.com/marcosantos98/jake.git
```
2. Compile
```
v .
```
3. Symlink
```
sudo ./jake sym
```

**DONE** :boom:

### Usage:

```
jake
	Fast path to `jake build`
jake init
    Create jakefile.json with user input and setup project structure
jake build [options]
    Build the current project
    Options:
	    run <args> - Run the project after build with given args
jake run <args>
    Run the project
	    args - arguments passed to java
jake test [options]
    Build and test
    Options:
	    run <classpath> - Run single test with given classpath. e.g marco.test.Test
jake sym
    Create soft link to `/usr/local/bin`
```

### TODO:

Check the end of `main.v` to know what is planned to be added to the project in the near future.

### Current features:

- Create project with simple command `jake init`
- Gather all the `.java` files and build them into a single jar file with `jake build`
- Run the final jar with `jake run` or `jake build run`
  - Can also specify args for the final jar with `jake build run [args]` or `jake run [args]`
- Only build source files that have been recently modified.
- External library support.
- Support for tests with JUnit `jake test`

## Testing Java:

Currently `jake` has an option called `include_testing` that sets JUnit as the test framework.

Note: `jake test` only builds test files, if you want change a main source file you need to call `jake` first and then `jake test` 

```json
{
  ...
  "include_testing" : true
}
```
After the setup, you can run `jake test` to run all the tests

## Remote libraries:

```json
{
    ...
    "repos": [
        "repo_url"
    ],
    "deps": [
        "junit:junit:4.13.2"
    ]
}
```

Jake uses the same format as gradle short version.
```
implementation 'junit:junit:4.13.2
```
