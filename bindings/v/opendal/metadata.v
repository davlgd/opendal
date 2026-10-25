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

import time

// EntryMode tells whether a path holds a file or a directory.
pub enum EntryMode {
	unknown
	file
	dir
}

// Metadata describes the object stored at a path.
// Fields that the service does not report are `none`.
pub struct Metadata {
pub:
	mode                EntryMode
	content_length      u64
	content_type        ?string
	content_encoding    ?string
	content_disposition ?string
	cache_control       ?string
	content_md5         ?string
	etag                ?string
	version             ?string
	last_modified       ?time.Time
}

// is_file reports whether the path holds a file.
pub fn (m Metadata) is_file() bool {
	return m.mode == .file
}

// is_dir reports whether the path holds a directory.
pub fn (m Metadata) is_dir() bool {
	return m.mode == .dir
}

// take_metadata copies C metadata into a Metadata and frees the C metadata.
fn take_metadata(meta &C.opendal_metadata) Metadata {
	last_modified_ms := C.opendal_metadata_last_modified_ms(meta)
	m := Metadata{
		mode:                match C.opendal_metadata_mode(meta) {
			1 { EntryMode.file }
			2 { EntryMode.dir }
			else { EntryMode.unknown }
		}
		content_length:      C.opendal_metadata_content_length(meta)
		content_type:        take_string(C.opendal_metadata_content_type(meta))
		content_encoding:    take_string(C.opendal_metadata_content_encoding(meta))
		content_disposition: take_string(C.opendal_metadata_content_disposition(meta))
		cache_control:       take_string(C.opendal_metadata_cache_control(meta))
		content_md5:         take_string(C.opendal_metadata_content_md5(meta))
		etag:                take_string(C.opendal_metadata_etag(meta))
		version:             take_string(C.opendal_metadata_version(meta))
		last_modified:       if last_modified_ms == -1 {
			none
		} else {
			time.unix_milli(last_modified_ms)
		}
	}
	C.opendal_metadata_free(meta)
	return m
}

// take_string copies a heap string returned by the C binding and frees it.
fn take_string(ptr &char) ?string {
	if ptr == unsafe { nil } {
		return none
	}
	s := unsafe { cstring_to_vstring(ptr) }
	C.opendal_string_free(ptr)
	return s
}

// Entry is one item returned by a listing.
pub struct Entry {
pub:
	// path is relative to the operator root.
	path string
	// name is the last segment of path; it ends with `/` for a directory.
	name     string
	metadata Metadata
}

// OperatorInfo identifies the service behind an Operator.
pub struct OperatorInfo {
pub:
	scheme string
	root   string
	name   string
}
