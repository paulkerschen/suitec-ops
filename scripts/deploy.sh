#!/bin/bash

# Fail the entire script when one of the commands in it fails
set -e

echo_usage() {
  echo "SYNOPSIS"
  echo "     ${0}  [-r remote] [-b branch] [-t tag] [-x]"; echo
  echo "DESCRIPTION"
  echo "Available options"; echo
  echo "     -b      Name of branch in remote repository. Required when deploy-by-tag option is not used."; echo
  echo "     -r      Name of remote (i.e., tracked) repository. The default is 'origin'."; echo
  echo "     -t      Name of tag in remote repository. Required when deploy-by-branch option is not used."; echo
  echo "     -x      After successful deployment, DO NOT start the server"; echo
  echo "ENVIRONMENT VARIABLES"; echo
  echo "     DOCUMENT_ROOT"
  echo "          Apache directory to which we copy SuiteC static files"; echo
  echo "     SUITEC_BASE_DIR"
  echo "          Base directory of SuiteC deployment"; echo
  echo "EXAMPLES"; echo
  echo "     # Deploy 'irish_dry_stout' branch using remote 'arthur_guinness' repository"
  echo "          ${0} -r arthur_guinness -b irish_dry_stout"; echo
  echo "     # Deploy qa branch using default remote (origin)"
  echo "          ${0} -b qa"; echo
  echo "     # Deploy tag 1.6"
  echo "          ${0} -t 1.6"; echo
  echo "     # Deploy tag 1.6 and DO NOT start the server"
  echo "          ${0} -t 1.6 -x"; echo
}

# Give script synopsis when no args are passed.
[[ $# -gt 0 ]] || { echo_usage; exit 1; }

cd "$(dirname ${0})"
scripts_dir="$(pwd)"

"${scripts_dir}/verify-suitec-base-dir.sh"

# Base directory of SuiteC deployment
cd "${SUITEC_BASE_DIR}"

# The important steps are recorded in time-stamped log file
logger="tee -a $(date +"${SUITEC_BASE_DIR}/logs/deploy_%Y-%m-%d-%H%M%S.log")"

log() {
  echo | ${logger}
  echo "${1}" | ${logger}
  echo | ${logger}
}

[[ "${DOCUMENT_ROOT}" ]] || { echo; echo "[ERROR] 'DOCUMENT_ROOT' is undefined"; echo_usage; exit 1; }

log "DOCUMENT_ROOT, the Apache directory to which we copy SuiteC static files, is set to: ${DOCUMENT_ROOT}"

# Default remote repository
git_remote="origin"
start_server=true

while getopts "b:r:t:x" arg; do
  case ${arg} in
    b)
      git_branch="${OPTARG}"
      ;;
    r)
      git_remote="${OPTARG}"
      ;;
    t)
      git_tag="${OPTARG}"
      ;;
    x)
      start_server=false
      ;;
  esac
done

# Validation
[[ "${git_tag}" || "${git_branch}" ]] || { log "[ERROR] You must specify branch or tag."; echo_usage; exit 1; }
[[ "${git_tag}" && "${git_branch}" ]] && { log "[ERROR] Specify branch or tag but NOT both."; echo_usage; exit 1; }

echo; echo "WARNING! In two seconds we will clear local changes with git reset. Control-c to abort."
sleep 2.5

log "Deploy SuiteC with command: ${0} ${*}"

# Clear local changes
git reset --hard HEAD

# Check out the branch or tag. If a tag is being deployed, the git HEAD will point to a commit and
# will end up in a "detached" state. As we shouldn't be committing on deployed code, this is considered OK

# Learn about remote branches
git fetch ${git_remote}

if [[ "${git_branch}" ]] ; then
  local_branch_name=$(date +"deploy-${git_remote}/${git_branch}_%Y-%m-%d-%H%M%S")
  log "git checkout branch: ${git_branch}"
  # Delete the local copy of the target branch (if any) as the upstream branch might have been rebased
  git rev-parse --verify ${git_branch} > /dev/null 2>&1 && git branch -D ${git_branch}
  log "Begin Git checkout of remote branch: ${git_remote}/${git_branch}"
  git checkout ${git_remote}/${git_branch} || { log "[ERROR] Unknown Git branch: ${git_branch}"; exit 1; }
else
  local_branch_name=$(date +"deploy-tags/${git_tag}_%Y-%m-%d-%H%M%S")
  log "git checkout tag: ${git_tag}"
  # Learn about remote tags
  git fetch -t ${git_remote}
  git checkout tags/${git_tag} || { log "[ERROR] Unknown Git tag: ${git_tag}"; exit 1; }
fi

# Create tmp branch
log "Create a local, temporary Git branch: ${local_branch_name}"
git checkout -b "${local_branch_name}"

log "The Git checkout is complete. Now remove the existing node_modules and re-install all npm dependencies"

# clean and npm install
/bin/find node_modules/ -mindepth 1 -maxdepth 1 -not -name 'col-*' -exec /bin/rm -rf '{}' \+
npm cache clean
npm install

log "Remove the existing bower dependencies and re-install"
rm -rf public/lib
node_modules/.bin/bower install

log "Run gulp build"
node_modules/.bin/gulp build

log "Kill the existing SuiteC process"
"${scripts_dir}/stop.sh"

log "Copy SuiteC static files to Apache directory: ${DOCUMENT_ROOT}"
cp -R target/* "${DOCUMENT_ROOT}"

log "Rotate 'forever' log files"
LOG_DIR=~/log
mkdir -p "${LOG_DIR}"

timestamp=$(date +"_%F_%H:%M:%S")

for f in $(ls ${LOG_DIR}/forever*.log); do
  mv "${f}" "${f/\.log/${timestamp}.log}"
done

if ${start_server}; then
  log "We are done. SuiteC has been started."
  "${scripts_dir}/start.sh"
else
  log "We are done and SuiteC was NOT started, as requested."
fi

exit 0
