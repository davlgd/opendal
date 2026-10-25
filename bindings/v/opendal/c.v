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

// The binding statically links libopendal_c built by `cargo build` in bindings/c, so programs
// do not depend on the build tree at run time.
// Pass `-d opendal_release` to use the `cargo build --release` artifact instead, and
// `-d opendal_shared` to link the shared library from the build tree instead of the static one.
#flag -I @VMODROOT/../c/include

$if opendal_shared ? {
	$if opendal_release ? {
		#flag -L @VMODROOT/../c/target/release
		#flag darwin -Wl,-rpath,@VMODROOT/../c/target/release
		#flag linux -Wl,-rpath,@VMODROOT/../c/target/release
	} $else {
		#flag -L @VMODROOT/../c/target/debug
		#flag darwin -Wl,-rpath,@VMODROOT/../c/target/debug
		#flag linux -Wl,-rpath,@VMODROOT/../c/target/debug
	}
	#flag -lopendal_c
} $else {
	$if opendal_release ? {
		#flag @VMODROOT/../c/target/release/libopendal_c.a
	} $else {
		#flag @VMODROOT/../c/target/debug/libopendal_c.a
	}
	// System libraries required by the Rust static library, as reported by
	// `cargo rustc --lib -- --print native-static-libs`.
	#flag darwin -framework Security -framework CoreFoundation -liconv -lSystem -lc -lm
	#flag linux -lgcc_s -lutil -lrt -lpthread -lm -ldl -lc
}

#include "opendal.h"

struct C.opendal_bytes {
mut:
	data     &u8
	len      uint
	capacity uint
}

struct C.opendal_error {
	code    int
	message C.opendal_bytes
}

struct C.opendal_operator {}

struct C.opendal_operator_options {}

struct C.opendal_metadata {}

struct C.opendal_lister {}

struct C.opendal_entry {}

struct C.opendal_reader {}

struct C.opendal_writer {}

struct C.opendal_operator_info {}

struct C.opendal_result_operator_new {
	op    &C.opendal_operator
	error &C.opendal_error
}

struct C.opendal_result_read {
mut:
	data  C.opendal_bytes
	error &C.opendal_error
}

struct C.opendal_result_exists {
	exists bool
	error  &C.opendal_error
}

struct C.opendal_result_stat {
	meta  &C.opendal_metadata
	error &C.opendal_error
}

struct C.opendal_result_list {
	lister &C.opendal_lister
	error  &C.opendal_error
}

struct C.opendal_result_lister_next {
	entry &C.opendal_entry
	error &C.opendal_error
}

struct C.opendal_result_operator_reader {
	reader &C.opendal_reader
	error  &C.opendal_error
}

struct C.opendal_result_operator_writer {
	writer &C.opendal_writer
	error  &C.opendal_error
}

struct C.opendal_result_reader_read {
	size  uint
	error &C.opendal_error
}

struct C.opendal_result_reader_seek {
	pos   u64
	error &C.opendal_error
}

struct C.opendal_result_writer_write {
	size  uint
	error &C.opendal_error
}

fn C.opendal_error_free(ptr &C.opendal_error)
fn C.opendal_bytes_free(ptr &C.opendal_bytes)
fn C.opendal_string_free(ptr &char)

fn C.opendal_operator_options_new() &C.opendal_operator_options
fn C.opendal_operator_options_set(options &C.opendal_operator_options, key &char, value &char)
fn C.opendal_operator_options_free(options &C.opendal_operator_options)

fn C.opendal_operator_new(scheme &char, options &C.opendal_operator_options) C.opendal_result_operator_new
fn C.opendal_operator_free(op &C.opendal_operator)
fn C.opendal_operator_write(op &C.opendal_operator, path &char, bytes &C.opendal_bytes) &C.opendal_error
fn C.opendal_operator_read(op &C.opendal_operator, path &char) C.opendal_result_read
fn C.opendal_operator_delete(op &C.opendal_operator, path &char) &C.opendal_error
fn C.opendal_operator_exists(op &C.opendal_operator, path &char) C.opendal_result_exists
fn C.opendal_operator_stat(op &C.opendal_operator, path &char) C.opendal_result_stat
fn C.opendal_operator_list(op &C.opendal_operator, path &char) C.opendal_result_list
fn C.opendal_operator_create_dir(op &C.opendal_operator, path &char) &C.opendal_error
fn C.opendal_operator_rename(op &C.opendal_operator, src &char, dest &char) &C.opendal_error
fn C.opendal_operator_copy(op &C.opendal_operator, src &char, dest &char) &C.opendal_error
fn C.opendal_operator_check(op &C.opendal_operator) &C.opendal_error
fn C.opendal_operator_reader(op &C.opendal_operator, path &char) C.opendal_result_operator_reader
fn C.opendal_operator_writer(op &C.opendal_operator, path &char) C.opendal_result_operator_writer

fn C.opendal_operator_info_new(op &C.opendal_operator) &C.opendal_operator_info
fn C.opendal_operator_info_free(info &C.opendal_operator_info)
fn C.opendal_operator_info_get_scheme(info &C.opendal_operator_info) &char
fn C.opendal_operator_info_get_root(info &C.opendal_operator_info) &char
fn C.opendal_operator_info_get_name(info &C.opendal_operator_info) &char

fn C.opendal_metadata_free(meta &C.opendal_metadata)
fn C.opendal_metadata_mode(meta &C.opendal_metadata) u8
fn C.opendal_metadata_content_length(meta &C.opendal_metadata) u64
fn C.opendal_metadata_last_modified_ms(meta &C.opendal_metadata) i64
fn C.opendal_metadata_cache_control(meta &C.opendal_metadata) &char
fn C.opendal_metadata_content_disposition(meta &C.opendal_metadata) &char
fn C.opendal_metadata_content_md5(meta &C.opendal_metadata) &char
fn C.opendal_metadata_content_type(meta &C.opendal_metadata) &char
fn C.opendal_metadata_content_encoding(meta &C.opendal_metadata) &char
fn C.opendal_metadata_etag(meta &C.opendal_metadata) &char
fn C.opendal_metadata_version(meta &C.opendal_metadata) &char

fn C.opendal_lister_next(lister &C.opendal_lister) C.opendal_result_lister_next
fn C.opendal_lister_free(lister &C.opendal_lister)
fn C.opendal_entry_path(entry &C.opendal_entry) &char
fn C.opendal_entry_name(entry &C.opendal_entry) &char
fn C.opendal_entry_metadata(entry &C.opendal_entry) &C.opendal_metadata
fn C.opendal_entry_free(entry &C.opendal_entry)

fn C.opendal_reader_read(reader &C.opendal_reader, buf &u8, len uint) C.opendal_result_reader_read
fn C.opendal_reader_seek(reader &C.opendal_reader, offset i64, whence i32) C.opendal_result_reader_seek
fn C.opendal_reader_free(reader &C.opendal_reader)

fn C.opendal_writer_write(writer &C.opendal_writer, bytes &C.opendal_bytes) C.opendal_result_writer_write
fn C.opendal_writer_close(writer &C.opendal_writer) &C.opendal_error
fn C.opendal_writer_free(writer &C.opendal_writer)
