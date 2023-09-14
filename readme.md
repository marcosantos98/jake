# Jake - CMake like tool for java

## :warning: WARNING

> This WIP tool. Beware that this probably contains bugs
> Also no documentation for now, check the `example` folder for a simple documentation.
> Check JakeProject struct in `main.v` for required fields and optional fields for jakefile.json.

### TODO:

Check the end of `main.v` to know what is planned to be added to the project in the near feature.

### Current features:

- Gather all the `.java` files and build them into a single jar file with `jake -b`
- Run the final jar with `jake -br`
    - Can also specify args for the final jar with `jake -br [args]`
- Only build source files that have been recently modified.