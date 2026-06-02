# Flutter Linux Desktop Build — Issue Report & Fix Guide

**Environment:** Ubuntu 24.04.4 LTS · Flutter 3.29.0 (stable) · Intel x86-64

---

## Problem

Running `flutter test integration_test/ -d linux` (or `flutter run -d linux`) on a
fresh Ubuntu 24.04 install with Flutter fails with a cascade of build errors.
Each error is a separate missing piece; fixing one reveals the next.

---

## Error 1 — No Linux platform configured

```
No Linux desktop project configured.
```

**Cause:** Flutter projects don't include Linux support by default.

**Fix:** Run once in the project root:
```bash
flutter create --platforms=linux .
```
This generates the `linux/` directory with CMakeLists and runner files.

---

## Error 2 — CMake can't link with clang (`-lstdc++` not found)

```
/usr/bin/ld: cannot find -lstdc++: No such file or directory
clang++: error: linker command failed with exit code 1
```

**Cause:** Flutter's Linux CMake build uses `clang++` by default. On Ubuntu 24.04,
`clang++` is installed but the GCC C++ standard library (`libstdc++`) is not in
clang's default linker search path.

**Fix:** Edit `linux/CMakeLists.txt` — add these two lines **before** the `project()`
declaration:
```cmake
cmake_minimum_required(VERSION 3.13)
set(CMAKE_C_COMPILER gcc)       # ← add this
set(CMAKE_CXX_COMPILER g++)     # ← add this
project(runner LANGUAGES CXX)
```
This forces the build to use `g++` which is fully configured on Ubuntu 24.04.
Also clear the CMake cache before the next run:
```bash
rm -rf build/linux
```

---

## Error 3 — C++ standard library headers not found (`type_traits`)

```
/usr/include/glib-2.0/glib/glib-typeof.h:43:10: fatal error: 'type_traits' file not found
```

**Cause:** `clang++` can't find GCC's C++ headers (`<type_traits>` lives in
`/usr/include/c++/13/`). If you applied the `g++` fix in Error 2 this error
disappears automatically.

**Fix (if staying with clang):**
```bash
sudo apt install libc++-dev libc++abi-dev
```

**Fix (preferred — already covered by Error 2 fix):** Switch to `g++` in
`CMakeLists.txt` as shown above.

---

## Error 4 — GStreamer not found (`audioplayers` dependency)

```
The following required packages were not found:
 - gstreamer-1.0
```

**Cause:** The `audioplayers` Flutter plugin requires GStreamer development headers
to compile on Linux. The runtime GStreamer libraries are usually pre-installed on
Ubuntu desktops, but the `-dev` packages (headers + `.pc` files) are not.

**Fix:**
```bash
sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
```

---

## Error 5 — GStreamer found by shell but not by CMake (`libunwind` hidden dependency)

```
-- Checking for module 'gstreamer-1.0'
--   Package 'libunwind', required by 'gstreamer-1.0', not found
```

**Cause:** Even after installing the GStreamer dev packages, CMake's
`pkg_check_modules` fails because `gstreamer-1.0.pc` lists `libunwind` as a
dependency, and its `.pc` file is not installed.

**Fix:**
```bash
sudo apt install libunwind-dev
```

---

## Error 6 — pkg-config search path not inherited by CMake subprocess

```
CMake Error: The following required packages were not found: gstreamer-1.0
```
(even after all dev packages are installed)

**Cause:** Flutter spawns CMake in a subprocess that doesn't always inherit
`PKG_CONFIG_PATH` from the shell. The `.pc` files are at
`/usr/lib/x86_64-linux-gnu/pkgconfig/` which is in the default path, but the
subprocess doesn't pick it up consistently.

**Fix:** Prefix the flutter test/run command with the explicit path:
```bash
PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig flutter test integration_test/ -d linux
```
Or add it permanently to `~/.bashrc`:
```bash
export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig
```

---

## Complete fix checklist (run once, in order)

```bash
# 1. System packages
sudo apt install \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  libunwind-dev \
  libc++-dev \
  libc++abi-dev

# 2. Add Linux platform to the Flutter project (run from project root)
flutter create --platforms=linux .

# 3. Edit linux/CMakeLists.txt — add these two lines before project():
#
#   set(CMAKE_C_COMPILER gcc)
#   set(CMAKE_CXX_COMPILER g++)
#
# Full top of file should look like:
#   cmake_minimum_required(VERSION 3.13)
#   set(CMAKE_C_COMPILER gcc)
#   set(CMAKE_CXX_COMPILER g++)
#   project(runner LANGUAGES CXX)

# 4. Add PKG_CONFIG_PATH to your shell (or prefix every flutter command)
export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig

# 5. Clear CMake cache and run
rm -rf build/linux
flutter test integration_test/ -d linux
```

---

## Root cause summary

Ubuntu 24.04 ships `clang++` as the default C++ compiler but without a complete
standalone toolchain (`libc++-dev` is not installed by default). Flutter's CMake
configuration does not fall back to `g++`, which is fully configured on every
standard Ubuntu install. Switching the project's `linux/CMakeLists.txt` to use
`g++` explicitly is the most reliable fix and requires no further system-level
changes beyond the GStreamer/libunwind packages (which are needed regardless of
which C++ compiler is used).
