#!/usr/bin/env bash
set -euo pipefail
# Create canonical CMake GTK4 project skeleton, storage API and start script
WS="${WORKSPACE:-/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app}"
mkdir -p "$WS/src" "$WS/build" "$WS/data" "$WS/test/vendor"
# CMakeLists with pkg-config IMPORTED_TARGET handling and sqlite fallback
cat >"$WS/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.16)
project(native_todo LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
find_package(PkgConfig REQUIRED)
# Use pkg-config to locate gtk4 and create imported target if available
pkg_check_modules(GTK4 REQUIRED IMPORTED_TARGET gtk4)
if (TARGET PkgConfig::GTK4)
  add_library(gtk4_pkgconfig INTERFACE IMPORTED)
  target_link_libraries(gtk4_pkgconfig INTERFACE PkgConfig::GTK4)
endif()
find_package(SQLite3 QUIET)
add_executable(native_todo src/main.cpp src/storage.cpp)
# includes
if (DEFINED GTK4_INCLUDE_DIRS)
  target_include_directories(native_todo PRIVATE ${GTK4_INCLUDE_DIRS} ${CMAKE_SOURCE_DIR}/src)
else()
  target_include_directories(native_todo PRIVATE ${CMAKE_SOURCE_DIR}/src)
endif()
# compile flags from pkg-config (if provided safely)
if (DEFINED GTK4_CFLAGS_OTHER)
  string(REPLACE "\"" "" GTK4_CFLAGS_SAFE "${GTK4_CFLAGS_OTHER}")
  target_compile_options(native_todo PRIVATE ${GTK4_CFLAGS_SAFE})
endif()
# link libraries
if (TARGET PkgConfig::GTK4)
  target_link_libraries(native_todo PRIVATE PkgConfig::GTK4)
elseif(DEFINED GTK4_LIBRARIES)
  target_link_libraries(native_todo PRIVATE ${GTK4_LIBRARIES})
endif()
if (SQLite3_FOUND)
  target_link_libraries(native_todo PRIVATE SQLite::SQLite3)
else()
  target_link_libraries(native_todo PRIVATE sqlite3)
endif()
# Tests
enable_testing()
add_executable(test_storage test/test_storage.cpp src/storage.cpp)
target_include_directories(test_storage PRIVATE ${CMAKE_SOURCE_DIR}/test/vendor ${CMAKE_SOURCE_DIR}/src)
if (SQLite3_FOUND)
  target_link_libraries(test_storage PRIVATE SQLite::SQLite3)
else()
  target_link_libraries(test_storage PRIVATE sqlite3)
endif()
add_test(NAME storage_test COMMAND test_storage)
CMAKE

# GTK4-compatible main that ensures data dir exists and accepts absolute path
cat >"$WS/src/main.cpp" <<'CPP'
#include <gtk/gtk.h>
#include "storage.h"
#include <string>
#include <filesystem>
static void on_activate(GApplication *app, gpointer user_data){
  GtkWidget *win = gtk_application_window_new(GTK_APPLICATION(app));
  gtk_window_set_title(GTK_WINDOW(win), "Native TODO");
  gtk_window_set_default_size(GTK_WINDOW(win), 300,200);
  gtk_widget_show(win);
}
int main(int argc, char **argv){
  std::string storage_path;
  if(argc>1) storage_path = argv[1]; else storage_path = std::string("data/todos.txt");
  std::filesystem::path p(storage_path);
  if(p.has_parent_path()) std::filesystem::create_directories(p.parent_path());
  GtkApplication *app = gtk_application_new("org.native.todo", G_APPLICATION_FLAGS_NONE);
  g_signal_connect(app, "activate", G_CALLBACK(on_activate), NULL);
  Storage s(storage_path);
  s.load();
  int status = g_application_run(G_APPLICATION(app), argc, argv);
  s.save();
  g_object_unref(app);
  return status;
}
CPP

# Storage API
cat >"$WS/src/storage.h" <<'H'
#pragma once
#include <string>
#include <vector>
class Storage{public:
  explicit Storage(const std::string &path);
  void load();
  void save() const;
  void add_item(const std::string &it);
  const std::vector<std::string>& get_items() const;
private:
  std::string path_;
  std::vector<std::string> items_;
};
H

cat >"$WS/src/storage.cpp" <<'CPP'
#include "storage.h"
#include <fstream>
#include <filesystem>
Storage::Storage(const std::string &path): path_(path){}
void Storage::load(){ items_.clear(); std::ifstream in(path_); std::string line; while(std::getline(in,line)) if(!line.empty()) items_.push_back(line); }
void Storage::save() const{ std::filesystem::path p(path_); if(p.has_parent_path()) std::filesystem::create_directories(p.parent_path()); std::ofstream out(path_); for(const auto &l: items_) out<<l<<"\n"; }
void Storage::add_item(const std::string &it){ items_.push_back(it); }
const std::vector<std::string>& Storage::get_items() const{ return items_; }
CPP

# Minimal test placeholder (Catch2 will be added in test step)
cat >"$WS/test/test_storage.cpp" <<'TEST'
#include <cassert>
#include "storage.h"
#include <cstdio>
int main(){
  const char *tmp = "test_data/tmp_test_storage.txt";
  std::remove(tmp);
  Storage s(tmp);
  s.add_item("one");
  s.save();
  Storage s2(tmp);
  s2.load();
  assert(!s2.get_items().empty());
  std::remove(tmp);
  return 0;
}
TEST

# .gitignore
cat >"$WS/.gitignore" <<'GIT'
/build
/native_app.pid
/native_app.log
/data/
GIT

# start script: validate binary, start with setsid, write pid after verifying running
cat >"$WS/start.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WS="${WORKSPACE:-/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app}"
BIN="$WS/build/native_todo"
LOG="$WS/native_app.log"
PIDFILE="$WS/native_app.pid"
mkdir -p "$WS/data"
if [ ! -x "$BIN" ]; then echo "Binary $BIN missing or not executable; run build step" >&2; exit 2; fi
export DISPLAY="${DISPLAY:-:99}"
export GDK_BACKEND="x11"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
# Start in new session to have predictable PGID
setsid "$BIN" "$WS/data/todos.txt" >>"$LOG" 2>&1 &
PID=$!
# wait briefly and verify
sleep 0.5
if ps -p "$PID" >/dev/null 2>&1; then
  echo "$PID" >"$PIDFILE"
  echo "$PID" >"$WS/native_app.last_pid"
  exit 0
else
  echo "Failed to start $BIN; check $LOG" >&2; exit 3
fi
SH
chmod +x "$WS/start.sh"

# Ensure file ownership for workspace is the invoking non-root user when possible
if [ "$(id -u)" -eq 0 ]; then
  INVOKER="${SUDO_USER:-${USER:-root}}"
  chown -R "$INVOKER":"$INVOKER" "$WS" 2>/dev/null || true
fi

echo "scaffold: files written to $WS"
