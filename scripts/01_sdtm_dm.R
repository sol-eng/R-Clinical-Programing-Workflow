# ============================================================================
# SDTM DM (Demographics) domain
# Raw -> SDTM using {sdtm.oak}
# Source: https://pharmaverse.github.io/examples/sdtm/dm.html
# ============================================================================

library(sdtm.oak)
library(haven)
library(dplyr)

# ---- Read in raw data --------------------------------------------------
# Reference: reading directly from {pharmaverseraw} instead of local XPT files
# dm_raw <- pharmaverseraw::dm_raw
# ds_raw <- pharmaverseraw::ds_raw
# ec_raw <- pharmaverseraw::ec_raw

# Restore the "IT." item-prefix on column names (XPT variable names can't
# contain ".", so these were saved as "IT_" -- see scripts/00_export_raw_to_xpt.R)
restore_it_prefix <- function(df) {
  names(df) <- sub("^IT_", "IT.", names(df))
  df
}

dm_raw <- restore_it_prefix(read_xpt("input_data/dm_raw.xpt"))
ds_raw <- restore_it_prefix(read_xpt("input_data/ds_raw.xpt"))
ec_raw <- restore_it_prefix(read_xpt("input_data/ec_raw.xpt"))

# ---- Create oak_id_vars -------------------------------------------------
dm_raw <- dm_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", raw_src = "dm_raw")

ds_raw <- ds_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", raw_src = "ds_raw")

ec_raw <- ec_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", raw_src = "ec_raw")

# ---- Read in controlled terminology ------------------------------------
study_ct <- read.csv("metadata/sdtm_ct.csv")

# ---- Reference dates configuration --------------------------------------
ref_date_conf_df <- tibble::tribble(
  ~raw_dataset_name, ~date_var,     ~time_var,      ~dformat,      ~tformat, ~sdtm_var_name,
  "ec_raw",       "IT.ECSTDAT", NA_character_, "dd-mmm-yyyy", NA_character_,     "RFXSTDTC",
  "ec_raw",       "IT.ECENDAT", NA_character_, "dd-mmm-yyyy", NA_character_,     "RFXENDTC",
  "ec_raw",       "IT.ECSTDAT", NA_character_, "dd-mmm-yyyy", NA_character_,      "RFSTDTC",
  "ec_raw",       "IT.ECENDAT", NA_character_, "dd-mmm-yyyy", NA_character_,      "RFENDTC",
  "dm_raw",            "IC_DT", NA_character_,  "mm/dd/yyyy", NA_character_,      "RFICDTC",
  "ds_raw",          "DSDTCOL",     "DSTMCOL",  "mm-dd-yyyy",         "H:M",     "RFPENDTC",
  "ds_raw",          "DEATHDT", NA_character_,  "mm/dd/yyyy", NA_character_,       "DTHDTC"
)

# ---- Map Topic Variable (SUBJID) ----------------------------------------
dm <- dm_raw %>%
  mutate(SUBJID = substr(PATNUM, 5, 8)) %>%
  select(oak_id, raw_source, patient_number, SUBJID)

# ---- Map rest of the variables ------------------------------------------
dm <- dm %>%
  assign_no_ct(
    raw_dat = dm_raw, raw_var = "IT.AGE", tgt_var = "AGE",
    id_vars = oak_id_vars()
  ) %>%
  hardcode_ct(
    raw_dat = dm_raw, raw_var = "IT.AGE", tgt_var = "AGEU", tgt_val = "Year",
    ct_spec = study_ct, ct_clst = "C66781", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = dm_raw, raw_var = "IT.SEX", tgt_var = "SEX",
    ct_spec = study_ct, ct_clst = "C66731", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = dm_raw, raw_var = "IT.ETHNIC", tgt_var = "ETHNIC",
    ct_spec = study_ct, ct_clst = "C66790", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = dm_raw, raw_var = "IT.RACE", tgt_var = "RACE",
    ct_spec = study_ct, ct_clst = "C74457", id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = dm_raw, raw_var = "PLANNED_ARM", tgt_var = "ARM",
    ct_spec = study_ct, ct_clst = "ARM", id_vars = oak_id_vars()
  ) %>%
  assign_no_ct(
    raw_dat = dm_raw, raw_var = "PLANNED_ARMCD", tgt_var = "ARMCD",
    id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = dm_raw, raw_var = "ACTUAL_ARM", tgt_var = "ACTARM",
    ct_spec = study_ct, ct_clst = "ARM", id_vars = oak_id_vars()
  ) %>%
  assign_no_ct(
    raw_dat = dm_raw, raw_var = "ACTUAL_ARMCD", tgt_var = "ACTARMCD",
    id_vars = oak_id_vars()
  )

# ---- Map reference date variables ---------------------------------------
raw_source_list <- list(ec_raw = ec_raw, ds_raw = ds_raw, dm_raw = dm_raw)

dm <- dm %>%
  oak_cal_ref_dates(ds_in = ., der_var = "RFSTDTC", min_max = "min",
                     ref_date_config_df = ref_date_conf_df, raw_source = raw_source_list) %>%
  oak_cal_ref_dates(ds_in = ., der_var = "RFENDTC", min_max = "max",
                     ref_date_config_df = ref_date_conf_df, raw_source = raw_source_list) %>%
  oak_cal_ref_dates(ds_in = ., der_var = "RFXSTDTC", min_max = "min",
                     ref_date_config_df = ref_date_conf_df, raw_source = raw_source_list) %>%
  oak_cal_ref_dates(ds_in = ., der_var = "RFXENDTC", min_max = "max",
                     ref_date_config_df = ref_date_conf_df, raw_source = raw_source_list) %>%
  oak_cal_ref_dates(ds_in = ., der_var = "RFICDTC", min_max = "min",
                     ref_date_config_df = ref_date_conf_df, raw_source = raw_source_list) %>%
  oak_cal_ref_dates(ds_in = ., der_var = "RFPENDTC", min_max = "max",
                     ref_date_config_df = ref_date_conf_df, raw_source = raw_source_list) %>%
  oak_cal_ref_dates(ds_in = ., der_var = "DTHDTC", min_max = "min",
                     ref_date_config_df = ref_date_conf_df, raw_source = raw_source_list)

# ---- Create SDTM derived variables ---------------------------------------
dm <- dm %>%
  mutate(
    STUDYID = dm_raw$STUDY,
    DOMAIN = "DM",
    USUBJID = paste0("01-", dm_raw$PATNUM),
    COUNTRY = dm_raw$COUNTRY,
    DTHFL = dplyr::if_else(is.na(DTHDTC), NA_character_, "Y")
  ) %>%
  assign_datetime(
    raw_dat = dm_raw, raw_var = "COL_DT", tgt_var = "DMDTC",
    raw_fmt = c("m/d/y"), id_vars = oak_id_vars()
  ) %>%
  derive_study_day(
    sdtm_in = ., dm_domain = ., tgdt = "DMDTC", refdt = "RFXSTDTC",
    study_day_var = "DMDY"
  )

saveRDS(dm, "data/sdtm_dm.rds")
cat("SDTM DM built:", nrow(dm), "rows,", ncol(dm), "cols\n")
