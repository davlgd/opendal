---
title: V
sidebar_label: Overview
slug: /bindings/v
description: The OpenDAL V binding — early-stage, built from source, wraps the C API to expose blocking storage operations.
---

# Apache OpenDAL™ V Binding

A [V](https://vlang.io) binding for OpenDAL, giving V programs blocking access to S3, GCS, Azure Blob, the local filesystem, and [50+ more services](/services) through one API backed by the Rust core. The services available are those compiled into the C library.

New to the model behind the API? Read [Concepts](../../03-concepts.mdx) first — the shared storage semantics and path and operation concepts every binding expresses through its own native API.

:::caution Early-stage / Experimental
This binding is **early-stage and a work in progress**. There are no pre-built packages, and breaking changes may occur. It must be built from source. It is not yet published to any package registry.
:::

## Status

Unreleased and experimental (version `0.1.0`). The V binding wraps the OpenDAL C binding (`libopendal_c`) through V's C interoperability, then exposes an idiomatic V layer on top. Only synchronous (blocking) operations are implemented.

It requires V built from the latest master, and is tested on macOS and Linux (glibc). Windows is not supported yet.

## Capabilities

`Operator` exposes the operations below. Which ones work depends on the capabilities of the service: an unsupported operation fails with `Code.unsupported`.

- **write** — write bytes to a path
- **read** — read the whole content of a path
- **stat** — fetch metadata (mode, size, content type, etag, version, last modified)
- **delete** — remove a path
- **exists** — check whether a path exists
- **list** — return the entries whose paths start with a prefix, one level deep (end the path with `/` to list a directory); **lister** streams them as a `Lister`
- **create_dir** — create a directory path
- **rename** and **copy** — move or duplicate a file
- **reader** and **writer** — stream content through a `Reader` (`io.Reader`, with `seek`) and a `Writer` (`io.Writer`)
- **check** and **info** — verify the configuration and report the scheme, root and name of the service

Failing operations return an `opendal.Error` that carries a `Code`, such as `.not_found` or `.unsupported`. Strings that contain a NUL byte or invalid UTF-8 are rejected with `Code.unexpected` before they reach the C library.

## Building

Requirements: V built from the latest master, GCC or Clang, and a Rust toolchain.

```shell
# From bindings/c/: build libopendal_c with the services you need
cargo build --features opendal/services-fs

# From bindings/v/: run the tests
v -cc cc test opendal/
```

The binding statically links `bindings/c/target/debug/libopendal_c.a`, so the programs you build do not depend on the build tree at run time. Build the C library with `cargo build --release` and pass `-d opendal_release` to V to link the release artifact. Pass `-d opendal_shared` to link the shared library instead.

Use `-cc cc` (or `-cc gcc`, `-cc clang`) to select the system compiler directly: the TCC compiler bundled with V may fail to link the Rust static library, and V then retries with the system compiler.

## Using the module in your project

Make the `bindings/v/opendal` directory visible to V, for example by linking it into your modules directory:

```shell
ln -s /path/to/opendal/bindings/v/opendal ~/.vmodules/opendal
```

Then import it:

```v
import opendal
```

## Useful Links

- **Source**: [`bindings/v/`](https://github.com/apache/opendal/tree/main/bindings/v)
- **Services & configuration**: [/services](/services)
- **C binding (underlying layer)**: [`bindings/c/`](https://github.com/apache/opendal/tree/main/bindings/c)
- **Contributing**: [`bindings/v/CONTRIBUTING.md`](https://github.com/apache/opendal/blob/main/bindings/v/CONTRIBUTING.md)

## Next steps

1. [Getting started](./02-getting-started.md) — build an operator, write and read data, inspect metadata, list a directory, and stream content.
