# ============================================================================
# Run the full raw -> SDTM -> ADaM -> TLG pipeline end to end.
# ============================================================================
source("scripts/01_sdtm_dm.R")
source("scripts/02_sdtm_ae.R")
source("scripts/03_adam_adsl.R")
source("scripts/04_adam_adae.R")
source("scripts/05_tlg_demographic.R")
source("scripts/06_tlg_adverse_events.R")
source("scripts/07_tlg_pdf_export.R")
source("scripts/08_tlg_plots.R")
