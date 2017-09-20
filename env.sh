#!/usr/bin/env bash

[ -z "$CROSSWIN" ] && export CROSSWIN="false" || export CROSSWIN="true"
UNAME=`uname -s`
export MACOS=$([ "$UNAME" == "Darwin" ] && echo true || echo false)
export LINUX=$([ "$UNAME" == "Linux" ] && echo true || echo false)
