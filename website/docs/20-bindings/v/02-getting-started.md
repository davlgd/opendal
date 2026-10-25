---
title: Getting started
sidebar_label: Getting started
description: Build an operator, write and read data, inspect metadata, list a directory, and stream content with the OpenDAL V binding.
---

# Getting started

Before running anything, build the C library the binding links against, with the services you need. The `memory` service is always available; the examples below also use `fs`:

```shell
# From bindings/c/
cargo build --features opendal/services-fs
```

## Your first program

The example below creates an operator backed by the in-memory service, writes a file, reads it back, checks its metadata, and deletes it. It needs no credentials and no external service.

```v file=bindings/v/examples/getting_started.v region=quickstart
```

Run it from `bindings/v/` with `v -cc cc run examples/getting_started.v`.

`new_operator` takes the service scheme and a map of service options. Each service documents its options on the [services](/services) pages:

```v
mut op := opendal.new_operator('fs', {
	'root': '/tmp/opendal'
})!
defer {
	op.free()
}
```

`Operator`, `Lister`, `Reader` and `Writer` hold native resources: release each with `free()` once, and do not use it afterwards.

The snippets below run inside a function that returns a result (`fn run() ! { ... }`), and the listing and streaming ones also need `import io`.

## Listing a directory

`list` returns the entries whose paths start with the given prefix, one level deep. End the path with `/` to list a directory; the directory itself is part of the result when it exists, as it does here after `create_dir`.

```v
op.create_dir('dir/')!
op.write('dir/a.txt', 'aaa'.bytes())!
op.write('dir/b.txt', 'bbb'.bytes())!

for entry in op.list('dir/')! {
	println('name=${entry.name} path=${entry.path} size=${entry.metadata.content_length}')
}
```

For large listings, `lister` streams the entries. `next` returns `io.Eof` once the listing is exhausted:

```v
mut lister := op.lister('dir/')!
defer {
	lister.free()
}
for {
	entry := lister.next() or {
		if err is io.Eof {
			break
		}
		return err
	}
	println(entry.path)
}
```

## Streaming content

`Writer` implements `io.Writer` and `Reader` implements `io.Reader`. Free each one with `defer` right after creating it, so that an error cannot leak it:

```v
mut w := op.writer('stream.bin')!
defer {
	w.free()
}
w.write('Hello, '.bytes())!
w.write('World!'.bytes())!
w.close()!

mut r := op.reader('stream.bin')!
defer {
	r.free()
}
mut content := []u8{}
mut buf := []u8{len: 4096}
for {
	n := r.read(mut buf) or {
		if err is io.Eof {
			break
		}
		return err
	}
	content << buf[..n]
}
println(content.bytestr())
```

The loop treats only `io.Eof` as the end of the content and propagates any other read error. In the tested V revision, `io.read_all` and `io.cp` can treat a read error as a successful end: `io.read_all` returns the bytes read so far, and `io.cp` can leave a partial copy.

`close()` completes the write. Until it succeeds, what the path holds depends on the service, and `free()` does not roll back a write that was not closed.

## Error handling

Fallible operations return a V result. OpenDAL failures are `opendal.Error` values whose `code` field tells what went wrong, while `Lister.next()` and `Reader.read()` signal their normal end with `io.Eof`:

| `Code` | Meaning |
|---|---|
| `.not_found` | Path does not exist |
| `.permission_denied` | Access denied |
| `.already_exists` | Path already exists |
| `.unsupported` | The service does not support the operation |
| `.config_invalid` | Operator configuration is invalid |
| `.unexpected` | Any other OpenDAL or binding error, including text arguments with a NUL byte or invalid UTF-8 |

The full set matches the C binding's `opendal_code` and is defined in `bindings/v/opendal/error.v`.

```v
data := op.read('missing.txt') or {
	if err is opendal.Error && err.code == .not_found {
		println('file not found')
		return
	}
	return err
}
println(data.bytestr())
```

## Running the binding's own tests

```shell
# From bindings/c/
cargo build --features opendal/services-fs

# From bindings/v/
v -cc cc test opendal/
```

The tests run against the in-memory service and against the local filesystem in a temporary directory; no credentials are required.
