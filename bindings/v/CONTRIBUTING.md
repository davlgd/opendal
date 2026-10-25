# Contributing

## Setup

To build the OpenDAL V binding locally, you need:

- [V](https://github.com/vlang/v) built from the latest master
- GCC or Clang
- A Rust toolchain, to build the C binding

## Build

Build the C binding first. The tests use the `memory` service, which is always available, and the `fs` service:

```shell
cd ../c
cargo build --features opendal/services-fs
```

## Test

```shell
cd ../v
v fmt -verify opendal/ examples/
v -cc cc test opendal/
v -cc cc -d opendal_shared test opendal/
v -cc cc run examples/getting_started.v
```

The binding links the static library by default; `-d opendal_shared` checks the shared library path as well.

The `fs` test writes into a temporary directory and fails when the C library was built without `services-fs`.

To check memory safety, run the tests with AddressSanitizer:

```shell
v -cc clang -cflags '-fsanitize=address' -ldflags -fsanitize=address test opendal/
```
