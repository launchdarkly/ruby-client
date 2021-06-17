#!/bin/bash

set -ue

# Standard test.sh for Ruby-based projects

#shellcheck source=/dev/null
source "$(dirname "$0")/set-gem-home.sh"

bundle exec rspec spec
