#!/bin/bash

set -ue

# Standard publish.sh for Ruby-based projects - we can assume build.sh has already been run

export GEM_HOME="${LD_RELEASE_TEMP_DIR}/gems"

# If we're running in CircleCI, the RubyGems credentials will be in an environment
# variable and need to be copied to a file
if [ -n "${LD_RELEASE_RUBYGEMS_API_KEY}" ]; then
  mkdir -p ~/.gem
  cat >~/.gem/credentials <<EOF
---
:rubygems_api_key: $LD_RELEASE_RUBYGEMS_API_KEY
EOF
  chmod 0600 ~/.gem/credentials
fi

# Since all Releaser builds are clean builds, we can assume that the only .gem file here
# is the one we just built
echo "Running gem push"
gem push ./*.gem || { echo "gem push failed" >&2; exit 1; }
