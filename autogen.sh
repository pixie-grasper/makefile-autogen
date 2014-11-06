#!/bin/sh

usage() {
  self=`echo $0 | sed 's/^.*\/\([^\/]*\)$/\1/'`
  cat <<EOS
Usage:
  \$ $self --help
      Show this page and exit.

  \$ $self
      Generate a Makefile.
      Note: $self reads \`autogen.conf' if is in readable.

  \$ $self --set-only
      Set variables (eg. TARGET, CC, CFLAGS, ...)
      but do not generate a Makefile.
      Note: Value's priorities are;
        default of $self < set by shell < written on autogen.conf

Syntax of autogen.conf:
  var = val

  e.g.
    CC  = clang
    CXX = clang++
    CXXFLAGS = -std=c++11 -Weverything
EOS
}

set_default_value() {
  true ${TARGET:='default-target-name'}
  true ${BUILD_DIR:='./build'}
  true ${SRCDIR_TOP:='.'}
  true ${CC:='gcc'}
  true ${CFLAGS:=''}
  true ${CXX:='g++'}
  true ${CXXFLAGS:=''}
  BUILD_DIR_REGEX=`echo $BUILD_DIR | sed 's.\/.\\\/.g'`
}

# Read the config.
if [ -r autogen.conf ]; then
  eval `cat autogen.conf | sed 's/^[ \t]*\([^= \t]*\)[ \t]*=[ \t]*\(.*\)$/\1="\2"/' | awk -F= '$2 {print $0}'`
fi

# Set variables to default iff. are not set.
set_default_value

if [ $# -ne 0 ]; then
  case $1 in
    "-h" | "--help" | "usage" )
      usage
      exit;;
    "--set-only" )
      exit;;
  esac
fi

# Create a temporary file.
TEMPFILE_ALL=`mktemp makefile.all.XXXXXX.tmp`
TEMPFILE_C=`mktemp makefile.c.XXXXXX.tmp`
TEMPFILE_CC=`mktemp makefile.cc.XXXXXX.tmp`
TEMPFILE_CPP=`mktemp makefile.cpp.XXXXXX.tmp`
TEMPFILE_C_ALL=`mktemp makefile.c_all.XXXXXX.tmp`
trap "rm $TEMPFILE_ALL $TEMPFILE_C $TEMPFILE_CC $TEMPFILE_CPP $TEMPFILE_C_ALL" EXIT

# find *c, *.cc, *.cpp, write to tempfile without ext.
find | grep -v '/\.' | sed 's/^.\///' > $TEMPFILE_ALL
cat $TEMPFILE_ALL | grep '\.c$'   | sed 's/\.c$//'   > $TEMPFILE_C
cat $TEMPFILE_ALL | grep '\.cc$'  | sed 's/\.cc$//'  > $TEMPFILE_CC
cat $TEMPFILE_ALL | grep '\.cpp$' | sed 's/\.cpp$//' > $TEMPFILE_CPP
cat $TEMPFILE_C $TEMPFILE_CC $TEMPFILE_CPP > $TEMPFILE_C_ALL

# Write to Makefile!
# Note: Because I don't know how to know
#         the source-directory is a subset or equals to the build-directory or not is,
#           I've commented out `rm -rf $BUILD_DIR'.
sed 's/  /\t/' > Makefile <<EOS
# Makefile generated on `date`

DEPS = `cat $TEMPFILE_C_ALL | sed "s/^/$BUILD_DIR_REGEX\//" | sed 's/$/.d/' | paste -s`
OBJS = `cat $TEMPFILE_C_ALL | sed "s/^/$BUILD_DIR_REGEX\//" | sed 's/$/.o/' | paste -s`
TARGET = $TARGET

CC = $CC
CFLAGS = $CFLAGS
CXX = $CXX
CXXFLAGS = $CXXFLAGS

default: \$(TARGET)
all: \$(TARGET)

\$(TARGET): \$(OBJS)
  \$(CXX) \$^ -o \$@

$BUILD_DIR/%.o: %.c
  \$(CC) \$(CXXFLAGS) -MMD -MP -c \$< -o \$@ -I $SRCDIR_TOP

$BUILD_DIR/%.o: %.cc
  \$(CXX) \$(CXXFLAGS) -MMD -MP -c \$< -o \$@ -I $SRCDIR_TOP

$BUILD_DIR/%.o: %.cpp
  \$(CXX) \$(CXXFLAGS) -MMD -MP -c \$< -o \$@ -I $SRCDIR_TOP

.PHONY: clean distclean
clean:
  -@rm -f \$(DEPS) \$(OBJS)

distclean: clean
  -@rm -f \$(TARGET) Makefile
#  -@rm -rf $BUILD_DIR

-include \$(DEPS)
EOS

# Create build directory
cat $TEMPFILE_C_ALL |\
  sed "s/^/$BUILD_DIR_REGEX\//" |\
  sed 's/\/[^\/]*$//' |\
  xargs mkdir -p > /dev/null 2>&1
