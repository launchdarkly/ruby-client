#!/bin/bash

set -ue

# Standard build.sh for Ruby-based projects that publish a gem

echo "Using gem $(gem --version)"

#shellcheck source=/dev/null
source "$(dirname "$0")/set-gem-home.sh"

# If the gemspec specifies a certain version of bundler, we need to make sure we install that version.
echo "Installing bundler"
GEMSPEC_BUNDLER_VERSION=$(sed -n -e "s/.*['\"]bundler['\"], *['\"]\([^'\"]*\)['\"]/\1/p" ./*.gemspec | tr -d ' ')
if [ -n "${GEMSPEC_BUNDLER_VERSION}" ]; then
  GEMSPEC_OPTIONS="-v ${GEMSPEC_BUNDLER_VERSION}"
else
  GEMSPEC_OPTIONS=""
fi
gem install bundler ${GEMSPEC_OPTIONS} || { echo "installing bundler failed" >&2; exit 1; }

echo; echo "Installing dependencies"
bundle install

# Build Ruby Gem - this assumes there is a single .gemspec file in the main project directory
# Note that the gemspec must be able to get the project version either from $LD_RELEASE_VERSION,
# or from somewhere in the source code that the project-specific update-version.sh has updated.
echo "Running gem build"
gem build ./*.gemspec || { echo "gem build failed" >&2; exit 1; }
