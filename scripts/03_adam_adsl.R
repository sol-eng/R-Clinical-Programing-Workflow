# ============================================================================
# ADaM ADSL (Subject-Level Analysis Dataset)
# SDTM -> ADaM using {admiral}, {metacore}, {metatools}, {xportr}
# Source: https://pharmaverse.github.io/examples/adam/adsl.html
#
# Uses {pharmaversesdtm} DM/DS/EX/AE/VS/SUPPDM as SDTM input (consistent with
# the site's own ADSL example) rather than the DM/AE domains built in
# scripts 01-02, since ADSL also needs DS/EX/VS/SUPPDM which weren't
# in scope for the raw->SDTM stage here.
# ============================================================================

library(metacore)
library(metatools)
library(pharmaversesdtm)
library(admiral)
library(xportr)
library(dplyr)
library(tidyr)
library(lubridate)
library(stringr)

# ---- Read in input SDTM data ----------------------------------------------
dm <- pharmaversesdtm::dm
ds <- pharmaversesdtm::ds
ex <- pharmaversesdtm::ex
ae <- pharmaversesdtm::ae
vs <- pharmaversesdtm::vs
suppdm <- pharmaversesdtm::suppdm

dm <- convert_blanks_to_na(dm)
ds <- convert_blanks_to_na(ds)
ex <- convert_blanks_to_na(ex)
ae <- convert_blanks_to_na(ae)
vs <- convert_blanks_to_na(vs)
suppdm <- convert_blanks_to_na(suppdm)

dm_suppdm <- combine_supp(dm, suppdm)

# ---- Read in metacore spec -------------------------------------------------
metacore_obj <- suppressWarnings(
  spec_to_metacore(path = "metadata/safety_specs.xlsx", where_sep_sheet = FALSE) %>%
    select_dataset("ADSL")
)

# ---- Pull through SDTM columns ---------------------------------------------
adsl_preds <- build_from_derived(
  metacore_obj,
  ds_list = list("dm" = dm_suppdm, "suppdm" = dm_suppdm),
  predecessor_only = FALSE, keep = FALSE
)

# ---- Grouping variables: AGEGR1/AGEGR1N and RACEN --------------------------
adsl_ct <- adsl_preds %>%
  create_cat_var(metacore_obj, ref_var = AGE, grp_var = AGEGR1, num_grp_var = AGEGR1N) %>%
  create_var_from_codelist(metacore = metacore_obj, input_var = RACE, out_var = RACEN)

# ---- Exposure derivations ---------------------------------------------------
ex_ext <- ex %>%
  derive_vars_dtm(dtc = EXSTDTC, new_vars_prefix = "EXST") %>%
  derive_vars_dtm(dtc = EXENDTC, new_vars_prefix = "EXEN", time_imputation = "last")

adsl_raw <- adsl_ct %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 |
      (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) & !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 |
      (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) & !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_dtm_to_dt(source_vars = exprs(TRTSDTM, TRTEDTM)) %>%
  derive_vars_dtm_to_tm(source_vars = exprs(TRTSDTM)) %>%
  derive_var_trtdurd() %>%
  derive_var_merged_exist_flag(
    dataset_add = ex,
    by_vars = exprs(STUDYID, USUBJID),
    new_var = SAFFL,
    false_value = "N",
    missing_value = "N",
    condition = (EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO")))
  )

# ---- Treatment variables ----------------------------------------------------
adsl <- adsl_raw %>%
  mutate(
    TRT01P = if_else(ARM %in% c("Screen Failure", "Not Assigned", "Not Treated"), "No Treatment", ARM),
    TRT01A = if_else(ACTARM %in% c("Screen Failure", "Not Assigned", "Not Treated"), "No Treatment", ACTARM)
  ) %>%
  create_var_from_codelist(metacore_obj, input_var = TRT01P, out_var = TRT01PN) %>%
  create_var_from_codelist(metacore_obj, input_var = TRT01A, out_var = TRT01AN)

# ---- Disposition variables ---------------------------------------------------
ds_ext <- derive_vars_dt(ds, dtc = DSSTDTC, new_vars_prefix = "DSST")

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ds_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(EOSDT = DSSTDT),
    filter_add = DSCAT == "DISPOSITION EVENT" & DSDECOD != "SCREEN FAILURE"
  )

format_eosstt <- function(x) {
  case_when(
    x %in% c("COMPLETED") ~ "COMPLETED",
    x %in% c("SCREEN FAILURE") ~ NA_character_,
    TRUE ~ "DISCONTINUED"
  )
}

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ds,
    by_vars = exprs(STUDYID, USUBJID),
    filter_add = DSCAT == "DISPOSITION EVENT",
    new_vars = exprs(EOSSTT = format_eosstt(DSDECOD)),
    missing_values = exprs(EOSSTT = "ONGOING")
  ) %>%
  derive_vars_dt(
    new_vars_prefix = "DTH",
    dtc = DTHDTC,
    highest_imputation = "M",
    date_imputation = "first"
  ) %>%
  derive_vars_merged(
    dataset_add = ds_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(RANDDT = DSSTDT),
    filter_add = DSDECOD == "RANDOMIZED"
  ) %>%
  derive_vars_merged(
    dataset_add = ds_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(SCRFDT = DSSTDT),
    filter_add = DSCAT == "DISPOSITION EVENT" & DSDECOD == "SCREEN FAILURE"
  ) %>%
  derive_vars_merged(
    dataset_add = ds_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(FRVDT = DSSTDT),
    filter_add = DSCAT == "OTHER EVENT" & DSDECOD == "FINAL RETRIEVAL VISIT"
  ) %>%
  derive_vars_duration(new_var = DTHADY, start_date = TRTSDT, end_date = DTHDT) %>%
  derive_vars_duration(new_var = LDDTHELD, start_date = TRTEDT, end_date = DTHDT, add_one = FALSE)

assign_randfl <- function(x) if_else(!is.na(x), "Y", NA_character_)
adsl <- adsl %>% mutate(RANDFL = assign_randfl(RANDDT))

# ---- Cause of death -----------------------------------------------------------
adsl <- adsl %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      event(
        dataset_name = "ae",
        condition = AEOUT == "FATAL",
        set_values_to = exprs(DTHCAUS = AEDECOD, DTHDOM = "AE"),
      ),
      event(
        dataset_name = "ds",
        condition = DSDECOD == "DEATH" & grepl("DEATH DUE TO", DSTERM),
        set_values_to = exprs(DTHCAUS = DSTERM, DTHDOM = "DS"),
      )
    ),
    source_datasets = list(ae = ae, ds = ds),
    tmp_event_nr_var = event_nr,
    order = exprs(event_nr),
    mode = "first",
    new_vars = exprs(DTHCAUS, DTHDOM)
  )

# ---- Apply metadata and write eSub XPT -----------------------------------------
dir.create("output", showWarnings = FALSE)

adsl_final <- adsl %>%
  drop_unspec_vars(metacore_obj) %>%
  check_variables(metacore_obj) %>%
  check_ct_data(metacore_obj, na_acceptable = TRUE) %>%
  order_cols(metacore_obj) %>%
  sort_by_key(metacore_obj) %>%
  xportr_type(metacore_obj, domain = "ADSL") %>%
  xportr_length(metacore_obj) %>%
  xportr_label(metacore_obj) %>%
  xportr_df_label(metacore_obj)

xportr_write(adsl_final, "output/adsl.xpt", metadata = metacore_obj, domain = "ADSL")
saveRDS(adsl_final, "data/adam_adsl.rds")

cat("ADSL built:", nrow(adsl_final), "rows,", ncol(adsl_final), "cols\n")
