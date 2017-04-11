#!/bin/bash

# Fail the entire script when one of the commands in it fails
set -e

echo_usage() {
  echo "SYNOPSIS"
  echo "     ${0} -d db_connection"; echo
  echo "DESCRIPTION"
  echo "Available options"
  echo "     -d      Database connection information in the form 'host:port:database:username'. Required."
}

while getopts "d:" arg; do
  case ${arg} in
    d)
      db_params=(${OPTARG//:/ })
      db_host=${db_params[0]}
      db_port=${db_params[1]}
      db_database=${db_params[2]}
      db_username=${db_params[3]}
      ;;
  esac
done

# Validation
[[ "${db_host}" && "${db_port}" && "${db_database}" && "${db_username}" ]] || {
  echo "[ERROR] You must specify complete database connection information."; echo
  echo_usage
  exit 1
}

# Because of foreign key constraints, we must populate tables in order of association. The 'canvas' table
# in the database remains unchanged.
declare -a tables=(courses 
                   users assets asset_users comments 
                   activity_types activities
                   categories assets_categories 
                   whiteboards whiteboard_members asset_whiteboard_elements whiteboard_elements chats)

# Check that all CSV files exist in the local directory.
for table in "${tables[@]}"; do
  [[ -f "${table}.csv" ]] || {
    echo "Aborting: file ${table}.csv not found in local directory."
    exit 1
  }
done

echo -n "Enter database password: "
read -s db_password; echo; echo

echo "Will push local CSV data to database ${db_database} at ${db_host}:${db_port}."; echo

push_csv() {
  echo "Copying ${1} to database..."

  # Format the header row as a comma-separated list for the Postgres copy command.
  header_row=`head -1 ${1}.csv`
  columns=${header_row//|/,}

  # Delete all rows from the specified table and replace with local CSV file contents.
  cat ${1}.csv | PGPASSWORD=${db_password} psql -h ${db_host} -p ${db_port} -d ${db_database} --username ${db_username}\
  -c "delete from ${1}; copy ${1} (${columns}) from stdin with (format csv, header true, delimiter '|')"
}

# Push CSV file contents to the database.
for table in "${tables[@]}"; do
  push_csv "${table}"
done

echo "Done."

exit 0
