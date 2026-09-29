# ============================================================================
# SDTM AE (Adverse Events) domain
# Raw -> SDTM using {sdtm.oak}
# Source: https://pharmaverse.github.io/examples/sdtm/ae.html
# ============================================================================

library(sdtm.oak)
library(haven)
library(dplyr)

# ---- Read in raw data ---------------------------------------------------
# Reference: reading directly from {pharmaverseraw} instead of local XPT files
# ae_raw <- pharmaverseraw::ae_raw

# Restore the "IT." item-prefix on column names (XPT variable names can't
# contain ".", so these were saved as "IT_" -- see scripts/00_export_raw_to_xpt.R)
restore_it_prefix <- function(df) {
  names(df) <- sub("^IT_", "IT.", names(df))
  df
}

ae_raw <- restore_it_prefix(read_xpt("input_data/ae_raw.xpt"))

# We need the DM domain (built in step 1) for RFXSTDTC/RFXENDTC to derive study day
dm <- readRDS("data/sdtm_dm.rds")

# ---- Create oak_id_vars --------------------------------------------------
ae_raw <- ae_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", raw_src = "ae_raw")

# ---- Read in controlled terminology --------------------------------------
study_ct <- read.csv("metadata/sdtm_ct.csv")

# ---- Map Topic Variable (AETERM) -----------------------------------------
# Note: no tgt_dat/pipe input here -- this creates the AE dataset from scratch
ae <- assign_no_ct(
  raw_dat = ae_raw, raw_var = "IT.AETERM", tgt_var = "AETERM",
  id_vars = oak_id_vars()
)

# ---- Map rest of the variables --------------------------------------------
ae <- ae %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "AEOUTCOME", tgt_var = "AEOUT",
    ct_spec = study_ct, ct_clst = "C66768", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "IT.AESEV", tgt_var = "AESEV",
    ct_spec = study_ct, ct_clst = "C66769", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "IT.AESER", tgt_var = "AESER",
    ct_spec = study_ct, ct_clst = "C66742", id_vars = oak_id_vars()
  ) %>%
  assign_no_ct(
    raw_dat = ae_raw, raw_var = "IT.AEACN", tgt_var = "AEACN",
    id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "IT.AEREL", tgt_var = "AEREL",
    ct_spec = study_ct, ct_clst = "AEREL", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "AESCAN", tgt_var = "AESCAN",
    ct_spec = study_ct, ct_clst = "C66742", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "AESCNO", tgt_var = "AESCONG",
    ct_spec = study_ct, ct_clst = "C66742", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "AEDIS", tgt_var = "AESDISAB",
    ct_spec = study_ct, ct_clst = "C66742", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "IT.AESDTH", tgt_var = "AESDTH",
    ct_spec = study_ct, ct_clst = "C66742", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "IT.AESHOSP", tgt_var = "AESHOSP",
    ct_spec = study_ct, ct_clst = "C66742", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "IT.AESLIFE", tgt_var = "AESLIFE",
    ct_spec = study_ct, ct_clst = "C66742", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ae_raw, raw_var = "AESOD", tgt_var = "AESOD",
    ct_spec = study_ct, ct_clst = "C66742", id_vars = oak_id_vars()
  ) %>%
  assign_datetime(
    raw_dat = ae_raw, raw_var = "AEDTCOL", tgt_var = "AEDTC",
    raw_fmt = c("m/d/y")
  ) %>%
  assign_datetime(
    raw_dat = ae_raw, raw_var = "IT.AESTDAT", tgt_var = "AESTDTC",
    raw_fmt = c("m/d/y"), id_vars = oak_id_vars()
  ) %>%
  assign_datetime(
    raw_dat = ae_raw, raw_var = "IT.AEENDAT", tgt_var = "AEENDTC",
    raw_fmt = c("m/d/y"), id_vars = oak_id_vars()
  )

# ---- Create SDTM derived variables -----------------------------------------
ae <- ae %>%
  dplyr::mutate(
    STUDYID = ae_raw$STUDY,
    DOMAIN = "AE",
    USUBJID = paste0("01-", ae_raw$PATNUM),
    AELLT = ae_raw$AELLT,
    AELLTCD = ae_raw$AELLTCD,
    AEDECOD = ae_raw$AEDECOD,
    AEPTCD = ae_raw$AEPTCD,
    AEHLT = ae_raw$AEHLT,
    AEHLTCD = ae_raw$AEHLTCD,
    AEHLGT = ae_raw$AEHLGT,
    AEHLGTCD = ae_raw$AEHLGTCD,
    AEBODSYS = ae_raw$AEBODSYS,
    AEBDSYCD = ae_raw$AEBDSYCD,
    AESOC = ae_raw$AESOC,
    AESOCCD = ae_raw$AESOCCD,
    AETERM = toupper(AETERM)
  ) %>%
  derive_seq(tgt_var = "AESEQ", rec_vars = c("USUBJID", "AETERM")) %>%
  derive_study_day(
    sdtm_in = ., dm_domain = dm, tgdt = "AESTDTC", refdt = "RFXSTDTC",
    study_day_var = "AESTDY"
  ) %>%
  derive_study_day(
    sdtm_in = ., dm_domain = dm, tgdt = "AEENDTC", refdt = "RFXENDTC",
    study_day_var = "AEENDY"
  ) %>%
  select(
    "STUDYID", "DOMAIN", "USUBJID", "AESEQ", "AETERM", "AELLT", "AELLTCD", "AEDECOD", "AEPTCD", "AEHLT", "AEHLTCD", "AEHLGT",
    "AEHLGTCD", "AEBODSYS", "AEBDSYCD", "AESOC", "AESOCCD", "AESEV", "AESER", "AEACN", "AEREL", "AEOUT", "AESCAN", "AESCONG",
    "AESDISAB", "AESDTH", "AESHOSP", "AESLIFE", "AESOD", "AEDTC", "AESTDTC", "AEENDTC", "AESTDY", "AEENDY"
  )

saveRDS(ae, "data/sdtm_ae.rds")
cat("SDTM AE built:", nrow(ae), "rows,", ncol(ae), "cols\n")
