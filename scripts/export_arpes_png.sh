#!/usr/bin/env bash
set -euo pipefail

arpes_mode=raw
arpes_thetay_offset=0
arpes_thetax_offset=0
arpes_azimuth_offset=0
arpes_inner_energy=
arpes_photon_energy=
arpes_workfunction=
arpes_slice_width=0.05

while [[ $# -gt 0 ]]; do
  case $1 in
    --momentum-space)
      arpes_mode=momentum
      shift
      ;;
    --thetay-offset|--thetax-offset|--azimuth-offset|--inner-energy|--photon-energy|--workfunction|--slice-width)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for $1" >&2
        exit 64
      fi
      case $1 in
        --thetay-offset) arpes_thetay_offset=$2 ;;
        --thetax-offset) arpes_thetax_offset=$2 ;;
        --azimuth-offset) arpes_azimuth_offset=$2 ;;
        --inner-energy) arpes_inner_energy=$2 ;;
        --photon-energy) arpes_photon_energy=$2 ;;
        --workfunction) arpes_workfunction=$2 ;;
        --slice-width) arpes_slice_width=$2 ;;
      esac
      shift 2
      ;;
    --help|-h)
      echo "Usage: $(basename "$0") [--momentum-space] [--thetax-offset VALUE] [--thetay-offset VALUE] [--azimuth-offset VALUE] [--inner-energy EV] [--photon-energy EV] [--workfunction EV] [--slice-width EV] /absolute/path/to/data.nxs"
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      exit 64
      ;;
    *)
      if [[ -n ${arpes_data_file:-} ]]; then
        echo "Only one data-file path is supported." >&2
        exit 64
      fi
      arpes_data_file=$1
      shift
      ;;
  esac
done

if [[ -z ${arpes_data_file:-} ]]; then
  echo "Usage: $(basename "$0") [--momentum-space] [--thetax-offset VALUE] [--thetay-offset VALUE] [--azimuth-offset VALUE] [--inner-energy EV] [--photon-energy EV] [--workfunction EV] [--slice-width EV] /absolute/path/to/data.nxs" >&2
  exit 64
fi

if [[ ! -f "$arpes_data_file" ]]; then
  echo "Data file not found: $arpes_data_file" >&2
  exit 66
fi

if command -v matlab >/dev/null 2>&1; then
  arpes_matlab_bin=$(command -v matlab)
elif [[ -x /Applications/MATLAB_R2023a.app/bin/matlab ]]; then
  arpes_matlab_bin=/Applications/MATLAB_R2023a.app/bin/matlab
else
  echo "MATLAB was not found on PATH or at the configured macOS application location." >&2
  exit 69
fi

arpes_script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ARPES_DATA_FILE="$arpes_data_file" \
ARPES_MODE="$arpes_mode" \
ARPES_THETAY_OFFSET="$arpes_thetay_offset" \
ARPES_THETAX_OFFSET="$arpes_thetax_offset" \
ARPES_AZIMUTH_OFFSET="$arpes_azimuth_offset" \
ARPES_INNER_ENERGY="$arpes_inner_energy" \
ARPES_PHOTON_ENERGY="$arpes_photon_energy" \
ARPES_WORKFUNCTION="$arpes_workfunction" \
ARPES_SLICE_WIDTH="$arpes_slice_width" \
  "$arpes_matlab_bin" -batch "run('$arpes_script_directory/export_arpes_plot.m')"
