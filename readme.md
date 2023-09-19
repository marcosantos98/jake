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

This times have been taken in the following enviromment:
- CPU: i7 9700k
- Java: OpenJDK 17
- OS: ArchLinux
- Project: [example/]()
- No dependencies or test famework in Gradle, only a basic application with the testing framework stripped.

The following times may be affected by the fact that `jake` is written in V which translate to C, and `Gradle` is written in Java. And we all know that C is just faster.

### TODO:

Check the end of `main.v` to know what is planned to be added to the project in the near feature.

### Current features:

- Gather all the `.java` files and build them into a single jar file with `jake -b`
- Run the final jar with `jake -br`
  - Can also specify args for the final jar with `jake -br [args]`
- Only build source files that have been recently modified.
- External library support. (Only local libraries for now)
- Support for tests with JUnit `jake -bt` or `jake -t`

## Testing Java:

Currently `jake` has an option called `include_testing` that setups JUnit as the test framework. You also need to specify the test class as package paths like `marco.test.Main`.

```json
{
  ...
  "include_testing" : true,
  "tests": [
    "marco.test.Main"
  ]
}
```

After the setup you can run `jake -t` to run all the tests or `jake -bt` to rebuild and run the tests.