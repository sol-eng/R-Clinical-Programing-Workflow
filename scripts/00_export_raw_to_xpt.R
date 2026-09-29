# ============================================================================
# One-off utility: export {pharmaverseraw} raw datasets to XPT files under
# input_data/, so the pipeline can be run against local SAS transport files
# instead of pulling directly from the {pharmaverseraw} package.
#
# SAS XPT variable names can't contain ".", so columns prefixed "IT." (the
# raw item-level prefix used throughout these datasets, e.g. "IT.AGE") are
# renamed to "IT_" before writing, and restored to "IT." when read back in
# scripts 01/02.
# ============================================================================

library(pharmaverseraw)
library(haven)

dir.create("input_data", showWarnings = FALSE)

sanitize_names <- function(df) {
  names(df) <- sub("^IT\\.", "IT_", names(df))
  df
}

write_xpt(sanitize_names(pharmaverseraw::dm_raw), "input_data/dm_raw.xpt")
write_xpt(sanitize_names(pharmaverseraw::ds_raw), "input_data/ds_raw.xpt")
write_xpt(sanitize_names(pharmaverseraw::ec_raw), "input_data/ec_raw.xpt")
write_xpt(sanitize_names(pharmaverseraw::ae_raw), "input_data/ae_raw.xpt")

cat("Wrote input_data/dm_raw.xpt, ds_raw.xpt, ec_raw.xpt, ae_raw.xpt\n")
