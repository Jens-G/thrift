Thrift D Software Library
=========================

License
-------

Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements. See the NOTICE file
distributed with this work for additional information
regarding copyright ownership. The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied. See the License for the
specific language governing permissions and limitations
under the License.

Testing
-------

D support in Thrift is covered by two sets of tests: first,
the unit test blocks contained in the D source files, and
second, the more extensive testing applications in the test/
subdirectory, which also make use of the Thrift compiler.
Both are built when running "make check", but only the
unit tests are immediately run, however – the separate test
cases typically run longer or require manual intervention.
It might also be prudent to run the independent tests,
which typically consist of a server and a client part,
against the other language implementations.

To build the unit tests on Windows, the easiest way might
be to manually create a file containing an empty main() and
invoke the compiler by running the following in the src/
directory (PowerShell syntax):

dmd -ofunittest -unittest -w $(dir -r -filter '*.d' -name)

Async and SSL
-------------
Using SSL with async is experimental (always has been) and
the unit test "async_test --ssl" hangs.  Use at your own
risk.

Breaking Changes
----------------

### 0.25.0

Two rules that the C++ library already applied now hold for D as well, so a
certificate D accepted before may be rejected now.

thrift.internal.ssl.authorize() consults the certificate's common name only when
the certificate carries no DNS subjectAltName extension. Previously the common
name was consulted whenever no subjectAltName entry had returned ALLOW, so a
certificate whose subjectAltName named other hosts got a second chance from a
common name that matched -- TDefaultClientAccessManager.verify returns SKIP for a
name that does not match, which made "names other hosts" and "names no hosts" the
same state at the fallthrough. RFC 6125 6.4.4 and RFC 9525 6.3 make the
subjectAltName the identity once it is present.

matchName(), which backs TDefaultClientAccessManager, no longer honours a
wildcard outside the leftmost label, per RFC 6125 6.4.3. Patterns such as
"thrift.*.*", "example.*.com" and "a.ev*.com" used to match and no longer do. A
wildcard in the leftmost label still covers at most one label, unchanged, so
"*.apache.org" matches "thrift.apache.org" but not "foo.bar.apache.org".

Certificates affected by either rule need reissuing with the host in their
subjectAltName, which is what every other TLS client already requires of them.
