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
import os

fn test_code_matches_c_binding() {
	assert int(Code.unexpected) == C.OPENDAL_UNEXPECTED
	assert int(Code.not_found) == C.OPENDAL_NOT_FOUND
	assert int(Code.already_exists) == C.OPENDAL_ALREADY_EXISTS
	assert int(Code.conflict) == C.OPENDAL_CONFLICT
	assert int(SeekMode.start) == C.OPENDAL_SEEK_SET
	assert int(SeekMode.current) == C.OPENDAL_SEEK_CUR
	assert int(SeekMode.end) == C.OPENDAL_SEEK_END
}

fn test_unknown_scheme_fails() {
	new_operator('no-such-service', {}) or {
		assert err is Error
		assert err.msg() != ''
		return
	}
	assert false, 'an unknown scheme must fail'
}

fn test_invalid_strings_fail_before_reaching_c() {
	mut failures := []string{}
	new_operator('memory', {
		'root': 'a\x00b'
	}) or { failures << err.msg() }
	mut op := new_operator('memory', {})!
	defer {
		op.free()
	}
	op.write('a\x00b', 'x'.bytes()) or { failures << err.msg() }
	op.read([u8(0xff), 0xfe].bytestr()) or { failures << err.msg() }
	op.rename('ok', 'bad\x00') or { failures << err.msg() }
	assert failures.len == 4
	assert failures.filter(it.contains('NUL byte')).len == 3
	assert failures.filter(it.contains('UTF-8')).len == 1
	assert !op.exists('a')!
}

fn test_sliced_path_is_not_read_past_its_end() {
	mut op := new_operator('memory', {})!
	defer {
		op.free()
	}
	full := 'short.txt-and-more'
	// A view shares the buffer of `full`, so no NUL byte follows its last character.
	view := unsafe { full.substr_unsafe(0, 9) }
	op.write(view, 'x'.bytes())!
	assert op.exists('short.txt')!
	assert !op.exists(full)!
}

fn test_info_reports_scheme_and_root() {
	mut op := new_operator('memory', {
		'root': '/myroot'
	})!
	defer {
		op.free()
	}
	info := op.info()
	assert info.scheme == 'memory'
	assert info.root == '/myroot/'
	op.check()!
}

fn test_write_read_stat_delete() {
	mut op := new_operator('memory', {})!
	defer {
		op.free()
	}
	op.write('hello.txt', 'Hello, World!'.bytes())!
	assert op.exists('hello.txt')!
	assert op.read('hello.txt')!.bytestr() == 'Hello, World!'

	meta := op.stat('hello.txt')!
	assert meta.is_file()
	assert !meta.is_dir()
	assert meta.content_length == 13

	op.delete('hello.txt')!
	assert !op.exists('hello.txt')!
}

fn test_write_empty_content() {
	mut op := new_operator('memory', {})!
	defer {
		op.free()
	}
	op.write('empty', []u8{})!
	assert op.read('empty')!.len == 0
	assert op.stat('empty')!.content_length == 0
}

fn test_missing_path_reports_not_found() {
	mut op := new_operator('memory', {})!
	defer {
		op.free()
	}
	op.read('missing') or {
		if err is Error {
			assert err.code == .not_found
			return
		}
		assert false, 'unexpected error type: ${err}'
	}
	assert false, 'reading a missing path must fail'
}

fn test_list_directory() {
	mut op := new_operator('memory', {})!
	defer {
		op.free()
	}
	op.create_dir('dir/')!
	op.write('dir/a.txt', 'a'.bytes())!
	op.write('dir/b.txt', 'bb'.bytes())!

	// The listing includes the directory itself.
	mut names := op.list('dir/')!.map(it.name)
	names.sort()
	assert names == ['a.txt', 'b.txt', 'dir/']

	mut lister := op.lister('dir/')!
	defer {
		lister.free()
	}
	mut files := 0
	for {
		entry := lister.next() or {
			assert err is io.Eof
			break
		}
		if entry.path.ends_with('.txt') {
			assert entry.path.starts_with('dir/')
			files++
		}
	}
	assert files == 2
}

fn test_reader_and_writer_stream() {
	mut op := new_operator('memory', {})!
	defer {
		op.free()
	}
	mut w := op.writer('stream.bin')!
	assert w.write('Hello, '.bytes())! == 7
	assert w.write('World!'.bytes())! == 6
	w.close()!
	w.free()

	mut r := op.reader('stream.bin')!
	defer {
		r.free()
	}
	assert io.read_all(reader: r)!.bytestr() == 'Hello, World!'

	assert r.seek(7, .start)! == 7
	mut buf := []u8{len: 5}
	assert r.read(mut buf)! == 5
	assert buf.bytestr() == 'World'
	assert r.seek(-1, .end)! == 12
}

fn test_fs_rename_and_copy() {
	root := os.join_path(os.temp_dir(), 'opendal_v_test_${os.getpid()}')
	defer {
		os.rmdir_all(root) or {}
	}
	// The C library must be built with `--features opendal/services-fs`.
	mut op := new_operator('fs', {
		'root': root
	})!
	defer {
		op.free()
	}
	op.write('src.txt', 'data'.bytes())!
	op.copy('src.txt', 'copy.txt')!
	op.rename('src.txt', 'moved.txt')!
	assert !op.exists('src.txt')!
	assert op.read('copy.txt')!.bytestr() == 'data'
	assert op.read('moved.txt')!.bytestr() == 'data'
	assert os.exists(os.join_path(root, 'moved.txt'))
}
