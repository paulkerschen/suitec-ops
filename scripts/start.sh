#!/bin/sh

# Abort immediately if a command fails
set -e

scripts_dir="$(dirname ${0})"

"${scripts_dir}/verify-suitec-base-dir.sh"

# Make sure nothing else is running before we start the app server
"${scripts_dir}/stop.sh"

# Base directory of SuiteC deployment
cd "${SUITEC_BASE_DIR}"

# Directory of the forever logs
LOG_DIR=~/log

# Start the app server
./node_modules/.bin/forever -a -l "$LOG_DIR/forever.log" -i "$LOG_DIR/forever_app.log" -e "$LOG_DIR/forever_app.log" -m 10 start app.js

exit 0
