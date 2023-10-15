# Jake - CMake like tool for java

## :warning: WARNING

> This WIP tool. Beware that this probably contains bugs
> Also no documentation for now, check the `example` folder for a simple documentation.
> Check JakeProject struct in `main.v` for required fields and optional fields for jakefile.json.

## Why:

Tools like gradle or maven becomes to slow when building simple projects due to the fact that they are design for large projects and work on a lot of different scenarios.

When using gradle to build the same code that is present in the `example` folder, without using any testing framework, I got the following results.

| Tool   | Time Fresh | Time After First Build | Modifying the Main.java |
| ------ | ---------- | ---------------------- | ---------------------- |
| Gradle | 0.860ms    | 0.750ms                | 0.830ms                |
| Jake   | 0.460ms    | 0.110ms                | 0.470ms                |

These times have been taken in the following environment:
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

### TODO:

Check the end of `main.v` to know what is planned to be added to the project in the near future.

### Current features:

- Gather all the `.java` files and build them into a single jar file with `jake build`
- Run the final jar with `jake run` or `jake build run`
  - Can also specify args for the final jar with `jake build run [args]` or `jake run [args]`
- Only build source files that have been recently modified.
- External library support. (Only local libraries for now)
- Support for tests with JUnit `jake test`

## Testing Java:

Currently `jake` has an option called `include_testing` that sets JUnit as the test framework.

```json
{
  ...
  "include_testing" : true
}
```
After the setup, you can run `jake test` to run all the tests

