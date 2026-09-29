# ============================================================================
# TLG: Demographic Table using {rtables} + {tern}
# Source: https://pharmaverse.github.io/examples/tlg/demographic.html
# ============================================================================

library(dplyr)
library(tern) # attaches rtables

adsl <- readRDS("data/adam_adsl.rds")

adsl <- adsl %>%
  filter(!ACTARM %in% "Screen Failure") %>%
  mutate(
    AGEGR1 = case_when(
      between(AGE, 18, 40) ~ "18-40",
      between(AGE, 41, 64) ~ "41-64",
      AGE > 64 ~ ">=65"
    ) %>%
      factor(levels = c("18-40", "41-64", ">=65"))
  ) %>%
  df_explicit_na()

vars <- c("AGE", "AGEGR1", "SEX", "RACE")
var_labels <- c("Age (yr)", "Age group", "Sex", "Race")

lyt <- basic_table(show_colcounts = TRUE) %>%
  split_cols_by(var = "ACTARM") %>%
  add_overall_col("All Patients") %>%
  analyze_vars(vars = vars, var_labels = var_labels)

demographic_table <- build_table(lyt, adsl)

dir.create("output", showWarnings = FALSE)
sink("output/demographic_table.txt")
print(demographic_table)
sink()

print(demographic_table)
