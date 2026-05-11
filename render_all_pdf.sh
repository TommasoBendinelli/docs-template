#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
OUTPUT_DIR="${SCRIPT_DIR}/pdf"
WRAPPER_DIR="${BUILD_DIR}/render_wrappers"
LEFT_PADDING_DELTA="0pt"
RIGHT_PADDING_DELTA="0pt"
FORCE_REBUILD=false
built_pdfs=()

usage() {
  cat <<EOF
Usage: ./render_all_pdf.sh [options]

Compile every top-level .tex document in this directory.

Options:
  --left-padding <delta>   Relative adjustment from the default 1in left margin.
  --right-padding <delta>  Relative adjustment from the default 1in right margin.
  --force                  Delete target build artifacts before compiling.
  --help                   Show this help message.

Examples:
  ./render_all_pdf.sh
  ./render_all_pdf.sh --force
  ./render_all_pdf.sh --left-padding -6pt --right-padding +12pt
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --left-padding)
      if [ "$#" -lt 2 ] || [[ "$2" == --* ]]; then
        echo "Error: --left-padding requires a value." >&2
        usage >&2
        exit 1
      fi
      LEFT_PADDING_DELTA="$2"
      shift 2
      ;;
    --right-padding)
      if [ "$#" -lt 2 ] || [[ "$2" == --* ]]; then
        echo "Error: --right-padding requires a value." >&2
        usage >&2
        exit 1
      fi
      RIGHT_PADDING_DELTA="$2"
      shift 2
      ;;
    --force)
      FORCE_REBUILD=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'." >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v latexmk >/dev/null 2>&1; then
  echo "Error: latexmk command not found." >&2
  exit 1
fi

if [ ! -f "${SCRIPT_DIR}/manual_style.sty" ]; then
  echo "Error: manual_style.sty not found in ${SCRIPT_DIR}" >&2
  exit 1
fi

mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" "${WRAPPER_DIR}"

write_file_if_changed() {
  local target="$1"
  local temp_file

  temp_file="$(mktemp "${target}.tmp.XXXXXX")"
  cat > "${temp_file}"
  if [ -f "${target}" ] && cmp -s "${temp_file}" "${target}"; then
    rm -f "${temp_file}"
    return 0
  fi
  mv "${temp_file}" "${target}"
}

cleanup_latexmk_target() {
  local stem="$1"
  local base="${BUILD_DIR}/${stem}"

  rm -f \
    "${base}.aux" \
    "${base}.bbl" \
    "${base}.blg" \
    "${base}.fdb_latexmk" \
    "${base}.fls" \
    "${base}.lof" \
    "${base}.log" \
    "${base}.lot" \
    "${base}.nav" \
    "${base}.out" \
    "${base}.pdf" \
    "${base}.run.xml" \
    "${base}.snm" \
    "${base}.synctex.gz" \
    "${base}.toc" \
    "${base}.vrb"
}

create_wrapper() {
  local tex_name="$1"
  local stem="${tex_name%.tex}"
  local wrapper_path="${WRAPPER_DIR}/${stem}.tex"

  {
    printf '\\documentclass[11pt]{article}\n'
    printf '\\def\\manualDocDefaultSourceBaseName{%s}\n' "${tex_name}"
    printf '\\def\\manualDocLeftPaddingDelta{%s}\n' "${LEFT_PADDING_DELTA}"
    printf '\\def\\manualDocRightPaddingDelta{%s}\n' "${RIGHT_PADDING_DELTA}"
    printf '\\usepackage{manual_style}\n'
    printf '\\input{../%s}\n' "${tex_name}"
  } | write_file_if_changed "${wrapper_path}"

  printf '%s' "${wrapper_path}"
}

compile_tex() {
  local tex_name="$1"
  local stem="${tex_name%.tex}"
  local source_file="${tex_name}"

  if ! grep -q '\\documentclass' "${SCRIPT_DIR}/${tex_name}"; then
    source_file="$(create_wrapper "${tex_name}")"
  fi

  echo "Compiling ${tex_name} -> ${OUTPUT_DIR}/${stem}.pdf"
  if [ "${FORCE_REBUILD}" = "true" ]; then
    cleanup_latexmk_target "${stem}"
  fi

  (
    cd "${SCRIPT_DIR}"
    latexmk -pdf -interaction=nonstopmode -halt-on-error -file-line-error \
      -output-directory="${BUILD_DIR}" "${source_file}"
  )

  if [ ! -f "${BUILD_DIR}/${stem}.pdf" ]; then
    echo "Error: expected rendered PDF at ${BUILD_DIR}/${stem}.pdf" >&2
    exit 1
  fi

  cp "${BUILD_DIR}/${stem}.pdf" "${OUTPUT_DIR}/${stem}.pdf"
  built_pdfs+=("${OUTPUT_DIR}/${stem}.pdf")
}

shopt -s nullglob
tex_files=("${SCRIPT_DIR}"/*.tex)
shopt -u nullglob

if [ "${#tex_files[@]}" -eq 0 ]; then
  echo "Error: no LaTeX files found in ${SCRIPT_DIR}" >&2
  exit 1
fi

for tex_file in "${tex_files[@]}"; do
  tex_name="$(basename "${tex_file}")"
  case "${tex_name}" in
    manual_docs_layout_config.tex)
      continue
      ;;
  esac
  compile_tex "${tex_name}"
done

echo "Done."
for pdf_file in "${built_pdfs[@]}"; do
  echo "Built: ${pdf_file#${SCRIPT_DIR}/}"
done

