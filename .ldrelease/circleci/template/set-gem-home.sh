#!/bin/bash

# helper script to set GEM_HOME and PATH for Ruby - must be sourced, not executed

mkdir -p "${LD_RELEASE_TEMP_DIR}/gems"
export GEM_HOME="${LD_RELEASE_TEMP_DIR}/gems"
export PATH="${GEM_HOME}/bin:${PATH}"
