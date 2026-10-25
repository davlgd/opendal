// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

module opendal

import encoding.utf8
import io

// Operator gives blocking access to one storage service.
// Release it with `free()` once done.
@[heap]
pub struct Operator {
mut:
	ptr &C.opendal_operator
}

// new_operator creates an Operator for the service named by `scheme`, such as
// `memory`, `fs` or `s3`, configured with the service `options`.
// The C library must be built with the matching `services-*` feature.
pub fn new_operator(scheme string, options map[string]string) !&Operator {
	c_scheme := c_string(scheme)!
	// Convert every option before allocating the C options, so that a failure cannot leak them.
	mut keys := []string{cap: options.len}
	mut values := []string{cap: options.len}
	for key, value in options {
		keys << c_string(key)!
		values << c_string(value)!
	}
	opts := C.opendal_operator_options_new()
	for i, key in keys {
		C.opendal_operator_options_set(opts, &char(key.str), &char(values[i].str))
	}
	result := C.opendal_operator_new(&char(c_scheme.str), opts)
	C.opendal_operator_options_free(opts)
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	return &Operator{
		ptr: result.op
	}
}

// free releases the native operator. The Operator must not be used afterwards.
pub fn (mut op Operator) free() {
	if op.ptr != unsafe { nil } {
		C.opendal_operator_free(op.ptr)
		op.ptr = unsafe { nil }
	}
}

// info returns the scheme, root and name of the service behind the Operator.
pub fn (op &Operator) info() OperatorInfo {
	info := C.opendal_operator_info_new(op.ptr)
	result := OperatorInfo{
		scheme: take_string(C.opendal_operator_info_get_scheme(info)) or { '' }
		root:   take_string(C.opendal_operator_info_get_root(info)) or { '' }
		name:   take_string(C.opendal_operator_info_get_name(info)) or { '' }
	}
	C.opendal_operator_info_free(info)
	return result
}

// check verifies that the service is reachable and correctly configured.
pub fn (op &Operator) check() ! {
	e := C.opendal_operator_check(op.ptr)
	if e != unsafe { nil } {
		return take_error(e)
	}
}

// write stores `data` at `path`, replacing any existing content.
pub fn (op &Operator) write(path string, data []u8) ! {
	c_path := c_string(path)!
	bytes := to_bytes(data)
	e := C.opendal_operator_write(op.ptr, &char(c_path.str), &bytes)
	if e != unsafe { nil } {
		return take_error(e)
	}
}

// read returns the whole content stored at `path`.
pub fn (op &Operator) read(path string) ![]u8 {
	c_path := c_string(path)!
	mut result := C.opendal_operator_read(op.ptr, &char(c_path.str))
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	data := if result.data.len == 0 {
		[]u8{}
	} else {
		unsafe { result.data.data.vbytes(int(result.data.len)).clone() }
	}
	C.opendal_bytes_free(&result.data)
	return data
}

// delete removes the object at `path`. Deleting a missing path succeeds.
pub fn (op &Operator) delete(path string) ! {
	c_path := c_string(path)!
	e := C.opendal_operator_delete(op.ptr, &char(c_path.str))
	if e != unsafe { nil } {
		return take_error(e)
	}
}

// exists reports whether an object exists at `path`.
pub fn (op &Operator) exists(path string) !bool {
	c_path := c_string(path)!
	result := C.opendal_operator_exists(op.ptr, &char(c_path.str))
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	return result.exists
}

// stat returns the metadata of the object at `path`.
// It fails with `Code.not_found` when the path does not exist.
pub fn (op &Operator) stat(path string) !Metadata {
	c_path := c_string(path)!
	result := C.opendal_operator_stat(op.ptr, &char(c_path.str))
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	return take_metadata(result.meta)
}

// create_dir creates the directory at `path`, which must end with `/`.
pub fn (op &Operator) create_dir(path string) ! {
	c_path := c_string(path)!
	e := C.opendal_operator_create_dir(op.ptr, &char(c_path.str))
	if e != unsafe { nil } {
		return take_error(e)
	}
}

// rename moves the file at `src` to `dest`.
// It fails with `Code.unsupported` when the service cannot rename.
pub fn (op &Operator) rename(src string, dest string) ! {
	c_src := c_string(src)!
	c_dest := c_string(dest)!
	e := C.opendal_operator_rename(op.ptr, &char(c_src.str), &char(c_dest.str))
	if e != unsafe { nil } {
		return take_error(e)
	}
}

// copy duplicates the file at `src` to `dest`.
// It fails with `Code.unsupported` when the service cannot copy.
pub fn (op &Operator) copy(src string, dest string) ! {
	c_src := c_string(src)!
	c_dest := c_string(dest)!
	e := C.opendal_operator_copy(op.ptr, &char(c_src.str), &char(c_dest.str))
	if e != unsafe { nil } {
		return take_error(e)
	}
}

// list returns the entries whose paths start with the prefix `path`, one level deep.
// End `path` with `/` to list a directory; the directory itself is part of the result
// when it exists. Use `lister` to stream large listings instead of loading them at once.
pub fn (op &Operator) list(path string) ![]Entry {
	mut lister := op.lister(path)!
	defer {
		lister.free()
	}
	mut entries := []Entry{}
	for {
		entries << lister.next() or {
			if err is io.Eof {
				break
			}
			return err
		}
	}
	return entries
}

// lister starts streaming the entries that `list` would return for `path`.
pub fn (op &Operator) lister(path string) !&Lister {
	c_path := c_string(path)!
	result := C.opendal_operator_list(op.ptr, &char(c_path.str))
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	return &Lister{
		ptr: result.lister
	}
}

// reader opens the object at `path` for streaming reads.
pub fn (op &Operator) reader(path string) !&Reader {
	c_path := c_string(path)!
	result := C.opendal_operator_reader(op.ptr, &char(c_path.str))
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	return &Reader{
		ptr: result.reader
	}
}

// writer opens `path` for streaming writes. `close()` completes the write; whether partial
// content is visible before that depends on the service.
pub fn (op &Operator) writer(path string) !&Writer {
	c_path := c_string(path)!
	result := C.opendal_operator_writer(op.ptr, &char(c_path.str))
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	return &Writer{
		ptr: result.writer
	}
}

// to_bytes borrows `data` as C bytes; the C binding rejects an empty buffer with a non-null pointer.
fn to_bytes(data []u8) C.opendal_bytes {
	return C.opendal_bytes{
		data:     if data.len == 0 { unsafe { nil } } else { &u8(data.data) }
		len:      uint(data.len)
		capacity: uint(data.len)
	}
}

// c_string returns a NUL-terminated copy of `s` to pass to the C binding, which reads up to
// the first NUL byte and requires valid UTF-8. V strings are not always NUL-terminated:
// borrowed slices share their parent's buffer.
fn c_string(s string) !string {
	if s.index_u8(0) != -1 {
		return Error{
			code:    .unexpected
			message: 'string passed to OpenDAL contains a NUL byte'
		}
	}
	if !utf8.validate_str(s) {
		return Error{
			code:    .unexpected
			message: 'string passed to OpenDAL is not valid UTF-8'
		}
	}
	return s.clone()
}
