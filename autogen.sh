#!/bin/sh

true ${TARGET:='default-target-name'}
true ${BUILD_DIR:='./build/'}
BUILD_DIR_REGEX=`echo $BUILD_DIR | sed 's.\/.\\\/.g'`

# Create a temporary file.
TEMPFILE=`mktemp makefile.XXXXXX.tmp`
trap "rm $TEMPFILE" EXIT

# find *.cc, write to TEMPFILE without ext.
find |\
  grep -v '/\.' |\
  grep '\.cc$' |\
  sed "s/^.\///" |\
  sed 's/.cc$//' > $TEMPFILE

# Write to Makefile!
sed 's/  /\t/' > Makefile <<EOS
# Makefile generated on `date`

DEPS = `cat $TEMPFILE | sed "s/^/$BUILD_DIR_REGEX/" | sed 's/$/.d/' | paste -s`
OBJS = `cat $TEMPFILE | sed "s/^/$BUILD_DIR_REGEX/" | sed 's/$/.o/' | paste -s`
TARGET = $TARGET

CXX = g++
CXXFLAGS =

default: \$(TARGET)
all: \$(TARGET)

\$(TARGET): \$(OBJS)
  \$(CXX) \$^ -o \$@

`cat $TEMPFILE |\
  sed "s/^\(.*\)$/$BUILD_DIR_REGEX\1.o: \1.cc .\/\1/" |\
  sed 's/\/[^\/]*$//' |\
  awk '{print $1 " " $2 "\n\t$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@ -I" $3}'`

.PHONY: clean distclean
clean:
  -rm -f \$(DEPS) \$(OBJS)

distclean: clean
  -rm -f \$(TARGET) Makefile
  -rm -rf $BUILD_DIR

-include \$(DEPS)
EOS

# Create build directory
cat $TEMPFILE |\
  sed "s/^/$BUILD_DIR_REGEX/" |\
  sed 's/\/[^\/]*$//' |\
  xargs mkdir -p > /dev/null 2>&1
