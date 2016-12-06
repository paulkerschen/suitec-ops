#!/bin/sh

# Abort immediately if a command fails
set -e

"$(dirname ${0})/verify-suitec-base-dir.sh"

# Base directory of SuiteC deployment
cd "${SUITEC_BASE_DIR}"

# Directory of the forever logs
LOG_DIR=~/log

# Stop the app server
./node_modules/.bin/forever -a -l "${LOG_DIR}/forever.log" -i "${LOG_DIR}/forever_app.log" -e "${LOG_DIR}/forever_app.log" -m 10 stopall

exit 0
