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

// Getting Started example for the V binding. It runs against the in-memory
// service with no credentials, so CI can execute it directly.

// ANCHOR: quickstart
import opendal

fn main() {
	// Initialize an operator for the "memory" service with no options.
	mut op := opendal.new_operator('memory', {})!
	defer {
		op.free()
	}

	// Write bytes to a path.
	op.write('hello.txt', 'Hello, World!'.bytes())!

	// Read them back.
	data := op.read('hello.txt')!
	println('read: ${data.bytestr()}')

	// Inspect metadata.
	meta := op.stat('hello.txt')!
	println('size: ${meta.content_length} bytes')
	println('is file: ${meta.is_file()}')

	// Delete, then check that the path is gone.
	op.delete('hello.txt')!
	op.stat('hello.txt') or {
		if err is opendal.Error && err.code == .not_found {
			println('done')
			return
		}
		panic(err)
	}
}
// ANCHOR_END: quickstart
