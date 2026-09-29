# ============================================================================
# TLG: Adverse Events Table using {rtables} + {tern}
# Source: https://pharmaverse.github.io/examples/tlg/adverse_events.html
# ============================================================================

library(dplyr)
library(tern) # attaches rtables
library(pharmaverseadam)

# Note: the safety_specs.xlsx ADAE sheet used in script 04 doesn't carry the
# full MedDRA hierarchy (AEBODSYS/AEDECOD) needed for this table, so -- exactly
# as the pharmaverse examples site itself does for the TLG stage -- we use the
# fuller {pharmaverseadam} reference ADaM datasets as input here.
adsl <- pharmaverseadam::adsl %>% df_explicit_na()
adae <- pharmaverseadam::adae %>%
  var_relabel(
    AEBODSYS = "MedDRA System Organ Class",
    AEDECOD = "MedDRA Preferred Term"
  ) %>%
  filter(SAFFL == "Y") %>%
  df_explicit_na()

split_fun <- drop_split_levels

lyt <- basic_table(show_colcounts = TRUE) %>%
  split_cols_by(var = "ACTARM") %>%
  add_overall_col(label = "All Patients") %>%
  analyze_num_patients(
    vars = "USUBJID",
    .stats = c("unique", "nonunique"),
    .labels = c(
      unique = "Total number of patients with at least one adverse event",
      nonunique = "Overall total number of events"
    )
  ) %>%
  split_rows_by(
    "AEBODSYS",
    child_labels = "visible",
    nested = FALSE,
    split_fun = split_fun,
    label_pos = "topleft",
    split_label = obj_label(adae$AEBODSYS)
  ) %>%
  summarize_num_patients(
    var = "USUBJID",
    .stats = c("unique", "nonunique"),
    .labels = c(
      unique = "Total number of patients with at least one adverse event",
      nonunique = "Total number of events"
    )
  ) %>%
  count_occurrences(
    vars = "AEDECOD",
    .indent_mods = -1L
  ) %>%
  append_varlabels(adae, "AEDECOD", indent = 1L)

adverse_events_table <- build_table(lyt, df = adae, alt_counts_df = adsl)

dir.create("output", showWarnings = FALSE)
sink("output/adverse_events_table.txt")
print(adverse_events_table)
sink()

print(adverse_events_table)
