#!/usr/bin/env bash

export CROSSWIN="false"
UNAME=`uname -s`
export MACOS=$([ "$UNAME" == "Darwin" ] && echo true || echo false)
export LINUX=$([ "$UNAME" == "Linux" ] && echo true || echo false)
