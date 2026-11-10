"""Unsigned, offline actual-source ownership checks; never build a plugin bundle."""

import io
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
BASELINE = "cb584a848fd762ec564ef3ef045af8181d2bb364"
FIXTURES = ROOT / ".github/tests/ownership"
SOURCES = (
    "4D Plugin API/4DPluginAPI.c",
    "4DPlugin-_o_PICTURE.cpp",
    "4D Plugin API/Classes/ARRAY_TEXT.cpp",
    "4D Plugin API/Classes/C_TEXT.cpp",
    "4D Plugin API/Classes/C_BLOB.cpp",
    "4D Plugin API/Classes/C_LONGINT.cpp",
)
PROBES = ("array-copy", "array-assign", "blob-copy", "blob-assign")


def run(*args, **kwargs):
    return subprocess.run(
        args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **kwargs
    )


def record(name, text):
    directory = os.environ.get("OWNERSHIP_LOG_DIR")
    if directory:
        target = Path(directory)
        target.mkdir(parents=True, exist_ok=True)
        with (target / f"{name}.log").open("x") as log:
            log.write(text)


@unittest.skipUnless(platform.system() == "Darwin", "requires macOS clang/Objective-C runtime")
class OwnershipTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="raw-picture-ownership-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.directory = Path(cls.temp.name)
        baseline = cls.directory / "baseline"
        baseline.mkdir()
        archive = subprocess.check_output(
            ["git", "archive", BASELINE, "4D Plugin API",
             "4DPlugin-_o_PICTURE.cpp", "4DPlugin-_o_PICTURE.h"], cwd=ROOT
        )
        with tarfile.open(fileobj=io.BytesIO(archive)) as files:
            files.extractall(baseline, filter="data")
        includes = cls.directory / "includes"
        for header in (
            "CoreFoundation/CoreFoundation.h", "Cocoa/Cocoa.h",
            "AppKit/AppKit.h", "CoreGraphics/CoreGraphics.h",
        ):
            target = includes / header
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('#include "platform.h"\n')
        # Verify the complete bundled SDK and ABI headers, not selected fragments.
        for source in (baseline / "4D Plugin API").glob("*"):
            if source.is_file():
                assert source.read_bytes() == (ROOT / "4D Plugin API" / source.name).read_bytes(), source
        cls.executables = {}
        compiler = shutil.which("clang++")
        assert compiler, "clang++ is required; no tool installation is performed"
        for name, tree in (("baseline", baseline), ("fixed", ROOT)):
            binary = cls.directory / name
            if name == "baseline":
                binary = cls.directory / "baseline-host"
            command = [
                compiler, "-std=c++17", "-g", "-O1",
                "-fsanitize=address,undefined", "-fno-sanitize-recover=all",
                "-fno-omit-frame-pointer", "-fno-objc-arc",
                "-fno-constant-cfstrings", "-fconstant-string-class=OwnershipString",
                "-Wno-deprecated-declarations", "-Wno-extern-c-compat",
                "-Wno-parentheses", "-Wno-unused-value",
                "-I", str(includes), "-I", str(FIXTURES),
                "-I", str(tree), "-I", str(tree / "4D Plugin API"),
                "-x", "objective-c++",
                *(str(tree / source) for source in SOURCES),
                str(FIXTURES / "host.mm"), "-lobjc", "-o", str(binary),
            ]
            result = run(*command)
            record(f"{name}-compile", result.stdout)
            assert result.returncode == 0, f"{name} compile:\n{result.stdout}"
            # Only runtime/libc/libc++/sanitizer imports; no Apple framework image,
            # filesystem, UI, platform-discovery, or real 4D implementation.
            imports = run("otool", "-L", str(binary), check=True).stdout
            record(f"{name}-imports", imports)
            assert ".framework/" not in imports, imports
            for line in imports.splitlines()[1:]:
                library = line.strip().split(" (", 1)[0]
                assert (
                    library in (
                        "/usr/lib/libobjc.A.dylib", "/usr/lib/libc++.1.dylib",
                        "/usr/lib/libSystem.B.dylib",
                    )
                    or library.endswith("libclang_rt.asan_osx_dynamic.dylib")
                ), library
            cls.executables[name] = binary
        cls.environment = dict(
            os.environ, ASAN_OPTIONS="detect_leaks=0:halt_on_error=1",
            UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1",
        )

    def test_baseline_and_fixed_controls(self):
        for name, binary in self.executables.items():
            with self.subTest(source=name):
                result = run(str(binary), "controls", env=self.environment)
                record(f"{name}-controls", result.stdout)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn("PASS controls fixtures=8", result.stdout)
                print(f"{name}: {result.stdout.strip()}")

    def test_baseline_named_copy_failures(self):
        for probe in PROBES:
            with self.subTest(probe=probe):
                result = run(str(self.executables["baseline"]), probe, env=self.environment)
                record(f"baseline-{probe}", result.stdout)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertRegex(result.stdout, "AddressSanitizer: (heap-use-after-free|attempting double-free)")
                print(f"baseline {probe}: expected sanitizer ownership failure")

    def test_fixed_copy_operations_prohibited(self):
        for probe in PROBES:
            with self.subTest(probe=probe):
                result = run(str(self.executables["fixed"]), probe, env=self.environment)
                record(f"fixed-{probe}", result.stdout)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn("PASS prohibited shallow copy", result.stdout)
                print(f"fixed {probe}: prohibited")


if __name__ == "__main__":
    unittest.main()
