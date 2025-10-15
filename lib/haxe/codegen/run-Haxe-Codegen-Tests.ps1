#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
# *
#   http://www.apache.org/licenses/LICENSE-2.0
# *
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

#---- failing tests --------------------------------------------

# expected to fail at Thrift Compiler
$FAIL_THRIFT = @(
	"BrokenConstants.thrift",        # intended to break
	"DuplicateImportsTest.thrift",   # subdir includes don't work here
	"Include.thrift")   # subdir includes don't work here

# expected to fail at Haxe Compiler
$FAIL_HAXE = @(
#    "Thrift5320.thrift"   
)

# unexpected but known bugs (TODO: fix them)
$KNOWN_BUGS = @(
#	"Base_One.thrift",
#	"Buses.thrift",
#	"Constants.thrift",
#	"ConstantsDemo.thrift",
#	"JavaDeepCopyTest.thrift",
#	"MaintenanceFacility.thrift",
#	"Midlayer.thrift",
#	"Transporters.thrift",
#	"Ultimate.thrift
    )

#---- functions --------------------------------------------

function FindThriftExe() {
	# prefer debug over release over path
	write-host -nonewline Looking for thrift.exe ...
	$exe = "thrift.exe"

	# if we have a freshly compiled one it might be a better choice
	@("Release","Debug") | foreach{
		if( test-path "$ROOTDIR\compiler\cpp\$_\thrift.exe") { $exe = "$ROOTDIR\compiler\cpp\$_\thrift.exe" }
		if( test-path "$ROOTDIR\compiler\cpp\compiler\$_\thrift.exe") { $exe = "$ROOTDIR\compiler\cpp\$_\compiler\thrift.exe" }
	}

	return $exe
}


function FindHaxe() {
	# prefer debug over release over path
	write-host -nonewline Looking for haxe.exe ...
	$exe = "haxe.exe"

	# TODO: add arbitraily complex code to locate a suitable HAXE.exe if it is not in the path

	return $exe
}


function InitializeFolder([string] $folder, [string] $pattern) {
	#write-host $folder\$pattern
	if(-not (test-path $folder)) {
		new-item $folder -type directory | out-null
	}
	pushd $folder
	gci . -include $pattern -recurse | foreach{ remove-item $_ }
	popd
}


function CopyFilesFrom([string] $source, $text) {
	#write-host "$source"
	if( ($source -ne "") -and (test-path $source)) {
		if( $text -ne $null) {
			write-host -foregroundcolor yellow Copying $text ...
		}

		pushd $source
		# recurse dirs
		gci . -directory | foreach {
			CopyFilesFrom "$_"
		}
		# files within
		gci *.thrift -file | foreach {
			#write-host $_
			$name = $_.name
			copy-item $_ "$TARGET\$name"
		}
		popd
	}
}

function CollectImports([string] $folder) {
	$import = "import ";

	# initialize hashset, add unwanted stuff to prevent against it
	$imports = [System.Collections.Generic.HashSet[String]] @()
	$imports.Add("import flash.errors.ArgumentError;")

	# scan files
	$retval = @()
	$files = gci $folder -include "*.hx" -recurse
	$files | foreach{
		$text = get-content $_
		$text | foreach{
			$line = $_
			if( $line.StartsWith($import)) {
				if( $imports.Add( $line)) {
					$retval += $line
				}
			}
		}
	}
	
	return $retval
}

function TestIdlFile([string] $idl) {
	# expected to fail at Thrift Compiler
	$filter = $false
	$FAIL_THRIFT | foreach {
		if( $idl -eq $_) {
			$filter = $true
			write-host "Skipping $_"
		}
	}
	if( $filter) { return $true }

	# compile IDL
	$genhaxe = "$TARGET\haxe\src\gen-haxe"
	InitializeFolder  "$TARGET\haxe\src"  "*.*"
	InitializeFolder  $genhaxe            "*.hx"
	gci "$genhaxe\*" | foreach{ remove-item $_ -recurse }
	&$THRIFT_EXE $VERBOSE -r --gen "haxe" --out $genhaxe  "$idl" | out-file "$TARGET\haxe\thrift.log"
	if( -not $?) {
		get-content "$TARGET\thrift.log" | out-default
		write-host -foregroundcolor red "Thrift compilation failed: $idl"
		return $false
	}
	
	# collect namespaces
	$imports = CollectImports $genhaxe

	# generate hxproj file
	$hxproj = "$TARGET\haxe\$TESTAPP.hxproj"
	if( -not (test-path $hxproj)) {
		copy-item "$PSScriptRoot\$TESTAPP.hxproj" $hxproj
	}

	# generate hxml file
	$hxml = "$TARGET\haxe\html5.hxml"
	if( -not (test-path $hxml)) {
		copy-item "$PSScriptRoot\html5.hxml" $hxml
	}

	# generate program main
	$testapp = "$TARGET\haxe\src\Main.hx"
	if( -not (test-path testapp)) {
		$lines = @()
		$lines += "package;"
		$lines += ""
		$imports | foreach{
			if( $_ -ne "True") {
				$lines += $_
			}
		}
		$lines += ""
		$lines += "class Main"
		$lines += "{"
		$lines += "    static public function main()"
		$lines += "    {"
		$lines += "    }"
		$lines += "}"
		$lines += ""
		$lines | set-content $testapp		
	}

	# try to compile the program
	# this should not throw any errors, warnings or hints
	$exe = "$TARGET\haxe\bin\html5\*.js"
	$log = "$TARGET\haxe\compile.log"
	if( test-path $exe) { remove-item $exe }
	&$HAXE_EXE --cwd "$TARGET\haxe"  "html5.hxml"  2> "$log"
	if( -not (test-path $exe)) {

		# expected to fail at Thrift Compiler
		$filter = $false
		$FAIL_HAXE | foreach {
			if( $idl -eq $_) {
				$filter = $true
				write-host ("Haxe compilation failed at "+$idl+" - as expected")
			}
		}
		$KNOWN_BUGS | foreach {
			if( $idl -eq $_) {
				$filter = $true
				write-host ("Haxe compilation failed at "+$idl+" - known issue (TODO)")
			}
		}
		if( $filter) { return $true }

		get-content "$log" | out-default
		write-host -foregroundcolor red "Haxe compilation failed: $idl"
		return $false
	}

	return $true
}

#---- main -------------------------------------------------
# CONFIGURATION BEGIN
# configuration settings, adjust as necessary to meet your system setup
$MY_THRIFT_FILES = "..\..\..\..\..\other_thrift_files"
$VERBOSE = ""  # set any Thrift compiler debug/verbose flag you want

# init
$ROOTDIR = $PSScriptRoot + "\..\..\.."

# try to find thrift.exe
$THRIFT_EXE = FindThriftExe
&$THRIFT_EXE -version
if( -not $?) {
	write-host -foregroundcolor red Missing thrift.exe
	exit 1
}

# try to find haxe.exe
$HAXE_EXE = FindHaxe
&$HAXE_EXE --version
if( -not $?) {
	write-host -foregroundcolor red Missing haxe.exe
	exit 1
}


# some helpers
$TARGET = "$ROOTDIR\..\thrift-testing"
$TESTAPP = "CodegenTest"

# create and/or empty target dirs
InitializeFolder  "$TARGET"        "*.thrift"
InitializeFolder  "$TARGET\haxe"   "*.*"

# recurse through thrift WC and "my thrift files" folder
# copies all .thrift files into thrift-testing
CopyFilesFrom "$ROOTDIR"            "Thrift IDL files"
CopyFilesFrom "$MY_THRIFT_FILES"    "Custom IDL files"

# codegen and compile all thrift files, one by one to prevent side effects
$count = 0
write-host -foregroundcolor yellow Running codegen tests ..
try {
	pushd "$TARGET"
	
	gci *.thrift -file | foreach {
		$count += 1
		$ok = TestIdlFile $_.name
		if( -not $ok) {
			throw "TEST FAILED"               # automated tests
			popd; pause; pushd "$TARGET"      # interactive / debug
		}
	}
	write-host -foregroundcolor green "Success ($count tests executed)"
	exit 0
} catch {
	write-host -foregroundcolor red $_
	exit 1
} finally {
	popd
}

#eof
