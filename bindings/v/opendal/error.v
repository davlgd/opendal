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

// Code identifies the kind of failure reported by OpenDAL.
// Its values match `opendal_code` in the C binding.
pub enum Code {
	unexpected
	unsupported
	config_invalid
	not_found
	permission_denied
	is_a_directory
	not_a_directory
	already_exists
	rate_limited
	is_same_file
	condition_not_match
	range_not_satisfied
	conflict
}

// Error is the error returned by every failing OpenDAL operation.
// Match it with `if err is opendal.Error { ... }` to inspect `code`.
pub struct Error {
pub:
	code    Code
	message string
}

// msg returns the message reported by OpenDAL.
pub fn (e Error) msg() string {
	return e.message
}

// code returns the numeric value of the error code.
pub fn (e Error) code() int {
	return int(e.code)
}

// take_error copies a C error into an Error and frees the C error.
fn take_error(e &C.opendal_error) IError {
	code := if e.code >= int(Code.unexpected) && e.code <= int(Code.conflict) {
		unsafe { Code(e.code) }
	} else {
		Code.unexpected
	}
	message := if e.message.len == 0 {
		''
	} else {
		unsafe { e.message.data.vstring_with_len(int(e.message.len)).clone() }
	}
	C.opendal_error_free(e)
	return Error{
		code:    code
		message: message
	}
}
