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

import io

// Lister streams the entries of a directory. Release it with `free()` once done.
@[heap]
pub struct Lister {
mut:
	ptr &C.opendal_lister
}

// next returns the next entry, or `io.Eof` once the listing is exhausted.
pub fn (mut l Lister) next() !Entry {
	result := C.opendal_lister_next(l.ptr)
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	if result.entry == unsafe { nil } {
		return io.Eof{}
	}
	entry := Entry{
		path:     take_string(C.opendal_entry_path(result.entry)) or { '' }
		name:     take_string(C.opendal_entry_name(result.entry)) or { '' }
		metadata: take_metadata(C.opendal_entry_metadata(result.entry))
	}
	C.opendal_entry_free(result.entry)
	return entry
}

// free releases the native lister.
pub fn (mut l Lister) free() {
	if l.ptr != unsafe { nil } {
		C.opendal_lister_free(l.ptr)
		l.ptr = unsafe { nil }
	}
}

// SeekMode sets the origin of `Reader.seek`. Its values match `OPENDAL_SEEK_*`.
pub enum SeekMode {
	start
	current
	end
}

// Reader streams the content of an object and implements `io.Reader`.
// Release it with `free()` once done.
@[heap]
pub struct Reader {
mut:
	ptr &C.opendal_reader
}

// read fills `buf` and returns the number of bytes read, or `io.Eof` at the end of the content.
pub fn (mut r Reader) read(mut buf []u8) !int {
	if buf.len == 0 {
		return 0
	}
	result := C.opendal_reader_read(r.ptr, &u8(buf.data), uint(buf.len))
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	if result.size == 0 {
		return io.Eof{}
	}
	return int(result.size)
}

// seek moves the read position by `offset` bytes from `whence` and returns the new position.
pub fn (mut r Reader) seek(offset i64, whence SeekMode) !u64 {
	result := C.opendal_reader_seek(r.ptr, offset, i32(whence))
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	return result.pos
}

// free releases the native reader.
pub fn (mut r Reader) free() {
	if r.ptr != unsafe { nil } {
		C.opendal_reader_free(r.ptr)
		r.ptr = unsafe { nil }
	}
}

// Writer streams content to an object and implements `io.Writer`.
// Call `close()` to store the content, then `free()` to release the writer.
@[heap]
pub struct Writer {
mut:
	ptr &C.opendal_writer
}

// write appends `buf` to the content and returns the number of bytes accepted.
pub fn (mut w Writer) write(buf []u8) !int {
	bytes := to_bytes(buf)
	result := C.opendal_writer_write(w.ptr, &bytes)
	if result.error != unsafe { nil } {
		return take_error(result.error)
	}
	return int(result.size)
}

// close completes the write. Until it succeeds, the content at the path depends on the
// service: some services already expose a partial or truncated object.
pub fn (mut w Writer) close() ! {
	e := C.opendal_writer_close(w.ptr)
	if e != unsafe { nil } {
		return take_error(e)
	}
}

// free releases the native writer. It does not roll back a write that was not closed.
pub fn (mut w Writer) free() {
	if w.ptr != unsafe { nil } {
		C.opendal_writer_free(w.ptr)
		w.ptr = unsafe { nil }
	}
}
