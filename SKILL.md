---
name: arpes-png-export
description: "Load OxA_CUT, OxA_MAP, or OxA_KZ photoemission data with loader_UI and export a 2D plot or Fermi-surface slice as a PNG, optionally after kconvert(). Use for supported ARPES data such as .nxs; skip other classes."
---

# ARPES PNG Export

Given one data-file path and a user-selected mode, export a 300 dpi PNG in the same directory:

- **Raw mode:** `<filename>.png` (2D cut or unconverted Fermi slice of 3D data)
- **Momentum-space mode:** `<filename>_ksp.png` (2D cut or converted Fermi slice of 3D data)

## Workflow

1. Confirm the file exists and obtain permission to read its directory and write the PNG there when required.
2. Ask whether the user wants the raw plot or momentum-space conversion if they have not specified it. Do not infer conversion from file type.
3. Confirm MATLAB can locate `loader_UI`. If it cannot, report the missing ARPES package rather than attempting a generic importer.
4. Run [scripts/export_arpes_png.sh](scripts/export_arpes_png.sh):

   ```sh
   # Raw data
   scripts/export_arpes_png.sh /absolute/path/to/data.nxs

   # Momentum-space data and Fermi surface, with angle offsets defaulting to 0
   scripts/export_arpes_png.sh --momentum-space /absolute/path/to/data.nxs

   # Angular map with calibrated angle, azimuth, and energy metadata
   scripts/export_arpes_png.sh --momentum-space --thetax-offset 1.2 \
     --thetay-offset -0.4 --azimuth-offset 2.0 \
     --photon-energy 166.0 --workfunction 4.78 /absolute/path/to/map.nxs

   # Photon-energy scan with user-supplied inner energy
   scripts/export_arpes_png.sh --momentum-space --inner-energy 15 \
     --slice-width 0.05 /absolute/path/to/kz-scan.nxs
   ```

5. Verify the PNG and report its path, loaded class, and any calibration values used. The helper reports `SKIPPED` for classes other than `OxA_CUT`, `OxA_MAP`, and `OxA_KZ`; do not present these as converted outputs.

## Momentum-space mode

After loading, inspect the class and metadata. Apply user-supplied values only to the relevant class:

- `OxA_CUT`: requires scalar `info.photon_energy` and `info.workfunction`; `info.thetay_offset` defaults to `0`.
- `OxA_MAP`: requires scalar `info.photon_energy` and `info.workfunction`; `info.thetax_offset`, `info.thetay_offset`, and `info.azimuth_offset` default to `0`.
- `OxA_KZ`: uses its photon-energy scan axis, `info.workfunction`, `info.thetay_offset` (default `0`), and `info.inner_energy`. The package constructor initializes inner energy to `15 eV`; report that default when used, or pass the user's value with `--inner-energy`. Do not replace a scan with one photon-energy value.

If a required photon energy, work function, or inner energy is missing or invalid, ask the user for its exact value. The helper calls `kconvert()` and names the result `<variable>_ksp`.

For `OxA_MAP` and `OxA_KZ`, the helper converts only source energy planes within the requested Fermi slice and calls `get_slice('z', 0, width)` on the converted object. This avoids creating an unnecessarily large full converted volume. The default width is `0.05 eV`: it is an energy thickness because the slice direction is `z` (`E - E_F`), not a momentum thickness in Å⁻¹. If no source plane falls in that range, the nearest plane is used. The resulting PNG is a Fermi-surface view, not a saved full 3D volume.

The helper starts a separate MATLAB batch session. Its figure does not appear in an already-open MATLAB Desktop; it writes the PNG directly instead. Do not overwrite a source data file. If the loader creates zero or multiple new variables, stop and report the names rather than choosing one.
