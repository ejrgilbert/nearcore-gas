export TESTDIR="${DIR}/tests"
export OUTDIR="${DIR}/target"

mkdir -p "${OUTDIR}"

# Logging functions
function log_ok() {
  GREEN_COLOR="\033[0;32m"
  DEFAULT="\033[0m"
  echo -e "${GREEN_COLOR}✔ [OK] ${1:-} ${DEFAULT}"
}

function log_warning() {
  YELLOW_COLOR="\033[33m"
  DEFAULT="\033[0m"
  echo -e "${YELLOW_COLOR}⚠ ${1:-} ${DEFAULT}"
}

function log_info() {
  BLUE_COLOR="\033[0;34m"
  DEFAULT="\033[0m"
  echo -e "${BLUE_COLOR}ℹ ${1:-} ${DEFAULT}"
}

function log_fail() {
  RED_COLOR="\033[0;31m"
  DEFAULT="\033[0m"
  echo -e "${RED_COLOR}❌ ${1:-}${DEFAULT}"
}

function error_exit() {
  log_fail "$*"
  exit 1
}

function merge() {
  stubs_file=$1
  module_file=$2
  wast_file=$3
  out_file=$4

  if ! cat "${stubs_file}" >"${out_file}"; then
    error_exit "Failed to print $stubs_file into the target $out_file"
  fi

  if ! printf "\n\n;; MODULE UNDER TEST\n\n" >>"${out_file}"; then
    error_exit "Failed to print newlines into the target $out_file"
  fi

  if ! cat "${module_file}" >>"${out_file}"; then
    error_exit "Failed to print $module_file into the target $out_file"
  fi

  if ! printf "\n(register \"near_gas\")\n\n;; START WAST TESTS\n\n" >>"${out_file}"; then
    error_exit "Failed to print newlines into the target $out_file"
  fi

  if ! cat "${wast_file}" >>"${out_file}"; then
    error_exit "Failed to print $wast_file into the target $out_file"
  fi

  log_ok "Successfully merged the gas hostmodule and wast tests into ==> ${out_file}"
}