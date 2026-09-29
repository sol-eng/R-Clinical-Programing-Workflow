# pharmaverse raw -> ADaM -> TLG pipeline

Implements the pharmaverse examples end-to-end workflow
(https://pharmaverse.github.io/examples/), scoped to a core slice: raw DM/AE
domains through SDTM, ADaM (ADSL/ADAE), and two TLG outputs (Demographics,
Adverse Events).

## Run

```r
source("run_all.R")
```

or run `scripts/01_*.R` .. `scripts/06_*.R` in order.

## Pipeline stages

| Script | Stage | Packages | Input | Output |
|---|---|---|---|---|
| `scripts/00_export_raw_to_xpt.R` | (one-off) Export raw -> XPT | `pharmaverseraw`, `haven` | `pharmaverseraw::dm_raw/ds_raw/ec_raw/ae_raw` | `input_data/*.xpt` |
| `scripts/01_sdtm_dm.R` | Raw -> SDTM DM | `sdtm.oak`, `haven` | `input_data/dm_raw.xpt`, `ds_raw.xpt`, `ec_raw.xpt` | `data/sdtm_dm.rds` |
| `scripts/02_sdtm_ae.R` | Raw -> SDTM AE | `sdtm.oak`, `haven` | `input_data/ae_raw.xpt` + `data/sdtm_dm.rds` | `data/sdtm_ae.rds` |
| `scripts/03_adam_adsl.R` | SDTM -> ADSL | `admiral`, `metacore`, `metatools`, `xportr` | `pharmaversesdtm::dm/ds/ex/ae/vs/suppdm` + `metadata/safety_specs.xlsx` | `data/adam_adsl.rds`, `output/adsl.xpt` |
| `scripts/04_adam_adae.R` | SDTM -> ADAE | `admiral`, `metacore`, `metatools`, `xportr` | `pharmaversesdtm::ae/ex` + `data/adam_adsl.rds` | `data/adam_adae.rds`, `output/adae.xpt` |
| `scripts/05_tlg_demographic.R` | ADaM -> Demographics table | `rtables`, `tern` | `data/adam_adsl.rds` | `output/demographic_table.txt` |
| `scripts/06_tlg_adverse_events.R` | ADaM -> AE table | `rtables`, `tern` | `pharmaverseadam::adsl/adae` (see note) | `output/adverse_events_table.txt` |
| `scripts/07_tlg_pdf_export.R` | Tables -> PDF | `rtables` (`export_as_pdf`) | `demographic_table`/`adverse_events_table` objects (re-sourced from 05/06 if absent) | `output/demographic_table.pdf`, `output/adverse_events_table.pdf` |
| `scripts/08_tlg_plots.R` | ADaM -> supporting plots | `ggplot2` | `data/adam_adsl.rds` + `pharmaverseadam::adsl/adae` | `output/figures/*.png`, `output/figures.pdf` |

Note: script 06 sources `pharmaverseadam::adsl/adae` rather than the ADaM
datasets built in scripts 03/04, because the example `safety_specs.xlsx` spec
sheet used for `metacore`/`xportr` doesn't carry the full MedDRA hierarchy
variables (AEBODSYS/AEDECOD/etc.) needed for the AE table -- this mirrors how
the pharmaverse examples site itself sources data for its TLG articles.
Script 08 uses `pharmaverseadam::adsl/adae` for the same reason for its AE-by-
SOC plot.

Script 07's AE table PDF (multi-page, landscape) can print benign
"height exceeds available space" warnings on a few pages -- an artifact of
`rtables` keeping each SOC's preferred-term rows from splitting across a page
boundary (`min_siblings`). The PDF is still complete and correctly paginated.

## TLG outputs

- `output/demographic_table.txt` / `.pdf` -- Demographics table (rtables/tern).
- `output/adverse_events_table.txt` / `.pdf` -- AE table by SOC/PT (rtables/tern).
- `output/figures/age_by_arm.png` -- age distribution boxplot by treatment arm.
- `output/figures/ae_incidence_by_soc.png` -- AE incidence (% patients) by
  System Organ Class and treatment arm, top 10 SOCs.
- `output/figures.pdf` -- both plots combined, one per page.

## Metadata

- `metadata/sdtm_ct.csv` -- SDTM controlled terminology, downloaded from
  `pharmaverse/examples` GitHub repo.
- `metadata/safety_specs.xlsx` -- ADaM specs (metacore input), downloaded from
  the same repo.

## Raw input data

`input_data/*.xpt` holds the raw DM/DS/EC/AE datasets (originally from
`{pharmaverseraw}`) as SAS transport files, generated once via
`scripts/00_export_raw_to_xpt.R`. Scripts 01/02 read from these XPT files by
default; the equivalent `pharmaverseraw::*_raw` lines are kept commented out
in each script as a reference/fallback. Because SAS XPT variable names can't
contain ".", columns prefixed `IT.` (e.g. `IT.AGE`) are renamed to `IT_` on
export and restored to `IT.` on read-in.

## Interactive teal app

`teal_app/` is a self-contained `{teal}` Shiny app (variable browser, data
table, and interactive Demographics/Adverse Events tables with a shared
filter panel) for exploring the pipeline's ADSL/ADAE data -- see
`teal_app/README.md` for module details and deployment instructions
(Posit Connect Cloud or a traditional Posit Connect server). Like scripts
06/08, it uses the `{pharmaverseadam}` reference ADSL/ADAE (copied locally
into `teal_app/data/`) rather than this pipeline's own derived ADAE, because
of the missing MedDRA hierarchy variables noted above.

## Scope

This covers DM/AE only (not VS), and ADSL/ADAE only (not ADVS/ADRS/ADTTE/
ADPC/ADPPK/ADER+), and Demographics/AE tables only (not PK listings). The full
pharmaverse examples site covers more domains/outputs; extending this
pipeline to those follows the same pattern (see
https://pharmaverse.github.io/examples/).
