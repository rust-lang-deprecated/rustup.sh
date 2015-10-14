#!/bin/sh

set -e -u

S="$(dirname $0)"

echo
echo "Running v1 metadata test suite"
echo

"$S/test-v1.sh"

echo
echo "Running v2 metadata test suite"
echo

"$S/test-v2.sh"
