# `build.zig` for hiredict

Provides a package to be used by the zig package manager for C programs.

# Status

| Refname   | Hiredict version | Zig `0.12.x` | Zig `0.13.x` | Zig `0.14.0-dev` |
|:----------|:----------------|:------------:|:------------:|:----------------:|
| `1.3.1`   | `1.3.1`         | ✅           | ✅           | ✅               |

# Usage

Add the dependency in your `build.zig.zon` by running the following command:

```
zig fetch --save=hiredict git+https://github.com/afirium/hiredict#1.3.1
```

You can then import hiredict in your `build.zig` with:

```
const hiredict = b.dependency("hiredict", .{
    .target = target,
    .optimize = optimize,
    .@"use-ssl" = true,
});
exe.linkLibrary(hiredict.artifact("hiredict"));
exe.linkLibrary(hiredict.artifact("hiredict_ssl")); // optional
```

A complete usage demonstration is provided in the [example](example) directory
