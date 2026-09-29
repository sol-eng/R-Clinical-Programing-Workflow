# ============================================================================
# ADaM ADAE (Adverse Events Analysis Dataset)
# SDTM -> ADaM using {admiral}, {metacore}, {metatools}, {xportr}
# Source: https://pharmaverse.github.io/examples/adam/adae.html
# ============================================================================

library(metacore)
library(metatools)
library(pharmaversesdtm)
library(pharmaverseadam)
library(admiral)
library(xportr)
library(dplyr)
library(lubridate)
library(stringr)

# ---- Read in input data ----------------------------------------------------
# Use the ADSL built in script 03 (falls back to pharmaverseadam::adsl if absent)
adsl <- if (file.exists("data/adam_adsl.rds")) readRDS("data/adam_adsl.rds") else pharmaverseadam::adsl
ae <- pharmaversesdtm::ae
ex <- pharmaversesdtm::ex

ae <- convert_blanks_to_na(ae)
ex <- convert_blanks_to_na(ex)

# ---- Load specifications for metacore --------------------------------------
metacore_obj <- suppressWarnings(
  spec_to_metacore(path = "metadata/safety_specs.xlsx", where_sep_sheet = FALSE) %>%
    select_dataset("ADAE")
)

# ---- Select ADSL variables --------------------------------------------------
adsl_vars <- exprs(TRTSDT, TRTEDT, DTHDT)

adae <- ae %>%
  derive_vars_merged(
    dataset_add = adsl,
    new_vars = adsl_vars,
    by_vars = exprs(STUDYID, USUBJID)
  )

# ---- Derive analysis dates --------------------------------------------------
adae <- adae %>%
  derive_vars_dt(
    new_vars_prefix = "AEN",
    dtc = AEENDTC,
    date_imputation = "last",
    highest_imputation = "M",
    flag_imputation = "auto"
  ) %>%
  derive_vars_dt(
    new_vars_prefix = "AST",
    dtc = AESTDTC,
    highest_imputation = "M",
    flag_imputation = "auto",
    min_dates = exprs(TRTSDT),
    max_dates = exprs(AENDT)
  ) %>%
  derive_vars_dy(
    reference_date = TRTSDT,
    source_vars = exprs(ASTDT, AENDT)
  )

# ---- Derive duration ---------------------------------------------------------
adae <- adae %>%
  derive_vars_duration(
    new_var = ADURN,
    new_var_unit = ADURU,
    start_date = ASTDT,
    end_date = AENDT
  )

# ---- Derive date of last dose ------------------------------------------------
ex <- ex %>% derive_vars_dt(dtc = EXENDTC, new_vars_prefix = "EXEN")

adae <- adae %>%
  derive_vars_joined(
    dataset_add = ex,
    by_vars = exprs(STUDYID, USUBJID),
    order = exprs(EXENDT),
    new_vars = exprs(LDOSEDT = EXENDT),
    join_vars = exprs(EXENDT),
    join_type = "all",
    filter_add = (EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) & !is.na(EXENDT),
    filter_join = EXENDT <= ASTDT,
    mode = "last"
  )

# ---- Derive analysis flags ---------------------------------------------------
adae <- adae %>%
  derive_var_trtemfl(
    start_date = ASTDT,
    end_date = AENDT,
    trt_start_date = TRTSDT,
    trt_end_date = TRTEDT
  ) %>%
  derive_var_ontrtfl(
    start_date = ASTDT,
    ref_start_date = TRTSDT,
    ref_end_date = TRTEDT,
    ref_end_window = 30
  )

# ---- Derive occurrence flags --------------------------------------------------
adae <- adae %>%
  mutate(TEMP_AESEVN = as.integer(factor(AESEV, levels = c("SEVERE", "MODERATE", "MILD")))) %>%
  derive_var_extreme_flag(
    new_var = AOCCIFL,
    by_vars = exprs(STUDYID, USUBJID),
    order = exprs(TEMP_AESEVN, ASTDT, AESEQ),
    mode = "first"
  ) %>%
  select(-TEMP_AESEVN)

# ---- Derive query variables ----------------------------------------------------
queries <- admiral::queries %>% filter(PREFIX %in% c("CQ01", "SMQ02"))

adae <- adae %>%
  derive_vars_query(dataset_queries = queries)

# ---- Add remaining ADSL variables ----------------------------------------------
adae <- adae %>%
  derive_vars_merged(
    dataset_add = select(adsl, !!!negate_vars(adsl_vars)),
    by_vars = exprs(STUDYID, USUBJID)
  )

# ---- Apply metadata and write eSub XPT ------------------------------------------
dir.create("output", showWarnings = FALSE)

adae_final <- adae %>%
  drop_unspec_vars(metacore_obj) %>%
  check_variables(metacore_obj) %>%
  check_ct_data(metacore_obj, na_acceptable = TRUE) %>%
  order_cols(metacore_obj) %>%
  sort_by_key(metacore_obj) %>%
  xportr_type(metacore_obj, domain = "ADAE") %>%
  xportr_length(metacore_obj) %>%
  xportr_label(metacore_obj) %>%
  xportr_df_label(metacore_obj)

xportr_write(adae_final, "output/adae.xpt", metadata = metacore_obj, domain = "ADAE")
saveRDS(adae_final, "data/adam_adae.rds")

cat("ADAE built:", nrow(adae_final), "rows,", ncol(adae_final), "cols\n")
