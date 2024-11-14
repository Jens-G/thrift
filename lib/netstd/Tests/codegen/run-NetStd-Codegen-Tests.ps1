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

# expected to fail at net Compiler
$FAIL_DOTNET = @(
)

# unexpected but known bugs (TODO: fix them)
$KNOWN_BUGS = @(
	"Base_One.thrift",
	"Buses.thrift",
	"Constants.thrift",
	"ConstantsDemo.thrift",
	"JavaDeepCopyTest.thrift",
	"MaintenanceFacility.thrift",
	"Midlayer.thrift",
	"Transporters.thrift",
	"Ultimate.thrift"
    )

$NET_VERSIONS = @(
	"net8",
	"net9"
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


function FindDotnet() {
	# prefer debug over release over path
	write-host -nonewline Looking for dotnet.exe ...
	$exe = "dotnet.exe"

	# TODO: add arbitraily complex code to locate a suitable dotnet.exe if it is not in the path

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
	#write-host -nonewline " $idl"
	InitializeFolder  "$TARGET\gen-netstd"    "*.cs"
	&$THRIFT_EXE $VERBOSE -r --gen "netstd:$net_version" $idl | out-file "$TARGET\thrift.log"
	if( -not $?) {
		get-content "$TARGET\thrift.log" | out-default
		write-host -foregroundcolor red "Thrift compilation failed: $idl"
		return $false
	}

	# generate solution
	if( -not (test-path "$TARGET\gen-netstd\$TESTAPP.sln")) {
		$lines = @()
		$lines += ""
		$lines += "Microsoft Visual Studio Solution File, Format Version 12.00"
		$lines += "# Visual Studio Version 17"
		$lines += "VisualStudioVersion = 17.11.35327.3"
		$lines += "MinimumVisualStudioVersion = 10.0.40219.1"
		$lines += "Project(`"{9A19103F-16F7-4668-BE54-9A1E7A4F7556}`") = `"TestProject`", `"TestProject.csproj`", `"{9501AFB9-21F2-4DBC-8775-1A98DDDE3D46}`""
		$lines += "EndProject"
		$lines += "Project(`"{9A19103F-16F7-4668-BE54-9A1E7A4F7556}`") = `"Thrift`", `"$ROOTDIR\lib\netstd\Thrift\Thrift.csproj`", `"{B0B34555-6212-4405-8B8A-DFA9899D827A}`""
		$lines += "EndProject"
		$lines += "Global"
		$lines += "    GlobalSection(SolutionConfigurationPlatforms) = preSolution"
		$lines += "        Debug|Any CPU = Debug|Any CPU"
		$lines += "        Release|Any CPU = Release|Any CPU"
		$lines += "    EndGlobalSection"
		$lines += "    GlobalSection(ProjectConfigurationPlatforms) = postSolution"
		$lines += "        {9501AFB9-21F2-4DBC-8775-1A98DDDE3D46}.Debug|Any CPU.ActiveCfg = Debug|Any CPU"
		$lines += "        {9501AFB9-21F2-4DBC-8775-1A98DDDE3D46}.Debug|Any CPU.Build.0 = Debug|Any CPU"
		$lines += "        {9501AFB9-21F2-4DBC-8775-1A98DDDE3D46}.Release|Any CPU.ActiveCfg = Release|Any CPU"
		$lines += "        {9501AFB9-21F2-4DBC-8775-1A98DDDE3D46}.Release|Any CPU.Build.0 = Release|Any CPU"
		$lines += "        {B0B34555-6212-4405-8B8A-DFA9899D827A}.Debug|Any CPU.ActiveCfg = Debug|Any CPU"
		$lines += "        {B0B34555-6212-4405-8B8A-DFA9899D827A}.Debug|Any CPU.Build.0 = Debug|Any CPU"
		$lines += "        {B0B34555-6212-4405-8B8A-DFA9899D827A}.Release|Any CPU.ActiveCfg = Release|Any CPU"
		$lines += "        {B0B34555-6212-4405-8B8A-DFA9899D827A}.Release|Any CPU.Build.0 = Release|Any CPU"
		$lines += "   EndGlobalSection"
		$lines += "   GlobalSection(SolutionProperties) = preSolution"
		$lines += "        HideSolutionNode = FALSE"
		$lines += "   EndGlobalSection"
		$lines += "   GlobalSection(ExtensibilityGlobals) = postSolution"
		$lines += "        SolutionGuid = {074CCCDB-A5DB-4CBF-AC18-10F9B373126A}"
		$lines += "   EndGlobalSection"
		$lines += "EndGlobal"
		$lines | set-content "$TARGET\gen-netstd\$TESTAPP.sln"
	}

	# generate program main - always, because of $net_version
	$lines = @()
	$lines += "<Project Sdk=`"Microsoft.NET.Sdk`">"
	$lines += ""
	$lines += "  <PropertyGroup>"
	$lines += "    <OutputType>Exe</OutputType>"
	$lines += "    <TargetFramework>$net_version.0</TargetFramework>"
	$lines += "    <Nullable>enable</Nullable>"
	$lines += "  </PropertyGroup>"
	$lines += ""
	$lines += "  <ItemGroup>"
	$lines += "    <ProjectReference Include=`"..\..\wc-JensG-haxe\lib\netstd\Thrift\Thrift.csproj`" />"
	$lines += "  </ItemGroup>"
	$lines += ""
	$lines += "</Project>"
	$lines += ""
	$lines | set-content "$TARGET\gen-netstd\$TESTAPP.csproj"

	# generate project file
	if( -not (test-path "$TARGET\gen-netstd\$TESTAPP.cs")) {
		$lines = @()
		$lines += "namespace $TESTAPP"
		$lines += "{"
		$lines += "    internal class Program"
		$lines += "    {"
		$lines += "        static void Main(string[] args)"
		$lines += "        {"
		$lines += "            System.Console.WriteLine(`"Hello, World!`");"
		$lines += "        }"
		$lines += "    }"
		$lines += "}"
		$lines | set-content "$TARGET\gen-netstd\$TESTAPP.cs"
	}

	# try to compile the program
	# this should not throw any errors, warnings or hints
	$exe = "$TARGET\gen-netstd\bin\Debug\$net_version.0\$TESTAPP.exe"
	if( test-path $exe) { remove-item $exe }
	&$DOTNET_EXE build "$TARGET\gen-netstd\$TESTAPP.sln"  | out-file "$TARGET\compile.log"
	if( -not (test-path $exe)) {

		# expected to fail at Thrift Compiler
		$filter = $false
		$FAIL_DOTNET | foreach {
			if( $idl -eq $_) {
				$filter = $true
				write-host ("C# compilation failed at "+$idl+" - as expected")
			}
		}
		$KNOWN_BUGS | foreach {
			if( $idl -eq $_) {
				$filter = $true
				write-host ("C# compilation failed at "+$idl+" - known issue (TODO)")
			}
		}
		if( $filter) { return $true }

		get-content "$TARGET\compile.log" | out-default
		write-host -foregroundcolor red "C# compilation failed: $idl"
		return $false
	}

	# The compiled program is now executed. If it hangs or crashes, we
	# have a serious problem with the generated code. 
	&"$exe" | out-file "$TARGET\exec.log"
	if( -not $?) {
		get-content "$TARGET\exec.log" | out-default
		write-host -foregroundcolor red "Test execution failed: $idl"
		return $false
	}
	return $true
}

#---- main -------------------------------------------------
# CONFIGURATION BEGIN
# configuration settings, adjust as necessary to meet your system setup
$MY_THRIFT_FILES = "..\..\..\..\..\..\other_thrift_files"
$VERBOSE = ""  # set any Thrift compiler debug/verbose flag you want

# init
$ROOTDIR = $PSScriptRoot + "\..\..\..\.."

# try to find thrift.exe
$THRIFT_EXE = FindThriftExe
&$THRIFT_EXE -version
if( -not $?) {
	write-host -foregroundcolor red Missing thrift.exe
	exit 1
}

# try to find dotnet.exe
$DOTNET_EXE = FindDotnet
&$DOTNET_EXE --version
if( -not $?) {
	write-host -foregroundcolor red Missing dotnet.exe
	exit 1
}


# some helpers
$TARGET = "$ROOTDIR\..\thrift-testing"
$TESTAPP = "TestProject"

# create and/or empty target dirs
InitializeFolder  "$TARGET"            "*.thrift"
InitializeFolder  "$TARGET\gen-netstd" "*.cs"

# recurse through thrift WC and "my thrift files" folder
# copies all .thrift files into thrift-testing
CopyFilesFrom "$ROOTDIR"            "Thrift IDL files"
CopyFilesFrom "$MY_THRIFT_FILES"    "Custom IDL files"

# codegen and compile all thrift files, one by one to prevent side effects
$count = 0
write-host -foregroundcolor yellow Running codegen tests ..
try {
	pushd "$TARGET"
	$NET_VERSIONS | foreach{
		$net_version = $_
		write-host -foregroundcolor cyan Targeting $net_version
		
		gci *.thrift -file | foreach {
			$count += 1
			$ok = TestIdlFile $_.name
			if( -not $ok) {
				throw "TEST FAILED"               # automated tests
				popd; pause; pushd "$TARGET"      # interactive / debug
			}
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
