# Apache OpenDAL™ V Binding

[![Status: Unreleased](https://img.shields.io/badge/status-unreleased-red)](https://github.com/apache/opendal/tree/main/bindings/v)

A [V](https://vlang.io) binding for [Apache OpenDAL](https://opendal.apache.org), built on top of the C binding. It gives blocking access to the local filesystem, memory, S3 and 50+ other storage services through one API.

> **Early-stage / Experimental.** The API may change between releases. There are no pre-built packages; you must build from source.

## Build

Requirements: [V](https://github.com/vlang/v) built from the latest master (the binding uses language changes that no tagged release includes yet), GCC or Clang, and a Rust toolchain. The binding is tested on macOS and Linux (glibc); Windows is not supported yet.

```shell
# From bindings/c/: build libopendal_c with the services you need
cargo build --features opendal/services-fs

# From bindings/v/: run the tests and the example
v -cc cc test opendal/
v -cc cc run examples/getting_started.v
```

The module includes `../c/include/opendal.h` and statically links `libopendal_c.a` from `../c/target/debug`, so the programs you build do not depend on the build tree at run time. Build the C library with `cargo build --release` and pass `-d opendal_release` to V to link `../c/target/release` instead. Pass `-d opendal_shared` to link the shared library from the build tree rather than the static one. Only OpenDAL is linked statically: the system libc and, on macOS, the system frameworks stay dynamic.

Use `-cc cc` (or `-cc gcc`, `-cc clang`) to select the system compiler directly: the TCC compiler bundled with V may fail to link the Rust static library, and V then retries with the system compiler.

The system libraries listed in `opendal/c.v` come from `cargo rustc --lib -- --print native-static-libs` for the tested targets. For another target, toolchain or feature set, run that command with the same features and adjust the flags if they differ.

The `memory` service is always available. Other services need the matching `opendal/services-*` feature when building the C library.

## Usage

```v
import opendal

fn main() {
	mut op := opendal.new_operator('fs', {
		'root': '/tmp/opendal'
	})!
	defer {
		op.free()
	}

	op.write('hello.txt', 'Hello, World!'.bytes())!
	println(op.read('hello.txt')!.bytestr())

	meta := op.stat('hello.txt')!
	println('${meta.content_length} bytes')

	for entry in op.list('/')! {
		println(entry.path)
	}
}
```

Which operations work depends on the service: an operation the service does not support fails with `Code.unsupported`. Failing operations return an `opendal.Error` that carries a `Code`, while `Lister.next()` and `Reader.read()` signal their normal end with `io.Eof`:

```v
op.read('missing') or {
	if err is opendal.Error && err.code == .not_found {
		println('not found')
	}
}
```

`Operator.reader()` and `Operator.writer()` stream content. `Reader` implements `io.Reader` and `Writer` implements `io.Writer`. Note that, in the tested V revision, `io.read_all` and `io.cp` can treat a read error as a successful end: `io.read_all` returns the bytes read so far, and `io.cp` can leave a partial copy. To propagate read errors, loop over `Reader.read()` and treat only `io.Eof` as the end. Call `Writer.close()` to complete a write. Until then, what the path holds depends on the service, and `free()` does not roll back a write that was not closed.

`Operator`, `Lister`, `Reader` and `Writer` are references to native resources: release each with `free()` once, and do not use it afterwards.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for local setup, build steps, and how to run the test suite.

## License and Trademarks

Licensed under the Apache License, Version 2.0: <http://www.apache.org/licenses/LICENSE-2.0>

Apache OpenDAL, OpenDAL, and Apache are either registered trademarks or trademarks of the Apache Software Foundation.
