# ============================================================================
# Interactive {teal} Shiny app for the pharmaverse raw-to-ADaM-to-TLG pipeline
#
# Provides interactive exploration of the ADSL/ADAE datasets built by the
# pipeline (see ../scripts and ../pipeline_report.qmd for the full raw ->
# SDTM -> ADaM derivation): a variable browser, a searchable/filterable data
# table, and the Demographics and Adverse Events summary tables, all wired
# to teal's global filter panel so users can slice by arm, sex, age, etc.
# and see every module update together.
#
# Deploy to Posit Connect with rsconnect::deployApp("teal_app") (run from the
# parent directory), or open this file and click "Run App" locally.
# ============================================================================

library(teal)
library(teal.data)
library(teal.transform)
library(teal.modules.general)
library(teal.modules.clinical)
library(dplyr)

# ---- Load data --------------------------------------------------------------
# Uses the {pharmaverseadam} reference ADSL/ADAE (full MedDRA hierarchy:
# AEBODSYS/AEDECOD/etc.), the same choice made for the AE table and AE-by-SOC
# plot in scripts/06_tlg_adverse_events.R and scripts/08_tlg_plots.R -- the
# abbreviated safety_specs.xlsx spec used to derive ADAE in scripts/04 doesn't
# carry those hierarchy variables. See AGENTS.md for details.
#
# "data/" resolves whether the working directory is this app's own folder
# (e.g. shiny::runApp("teal_app"), or how Connect/rsconnect run it) or the
# project root (e.g. source("teal_app/app.R") from the parent project). Check
# for the specific file, not just the directory -- the project root also has
# its own (unrelated) data/ folder from earlier pipeline stages.
data_dir <- if (file.exists("data/adsl.rds")) "data" else file.path("teal_app", "data")
adsl <- readRDS(file.path(data_dir, "adsl.rds"))
adae <- readRDS(file.path(data_dir, "adae.rds"))

# tm_t_summary()/tm_t_events() (tern) require the arm variable to be a
# factor -- as saved, ACTARM/ARM/TRT01A/TRT01P are plain character columns.
arm_cols <- c("ACTARM", "ARM", "TRT01A", "TRT01P")
adsl <- adsl |>
  dplyr::mutate(dplyr::across(dplyr::any_of(arm_cols), as.factor))
adae <- adae |>
  dplyr::mutate(dplyr::across(dplyr::any_of(arm_cols), as.factor))

# ---- Build the teal_data object ---------------------------------------------
data <- teal_data(
  ADSL = adsl,
  ADAE = adae,
  join_keys = default_cdisc_join_keys[c("ADSL", "ADAE")]
)

# ---- Variable choices for the clinical table modules -------------------------
arm_vars <- intersect(c("ACTARM", "ARM", "TRT01A", "TRT01P"), names(adsl))
demog_summary_vars <- intersect(
  c("AGE", "AGEGR1", "SEX", "RACE", "ETHNIC", "COUNTRY", "SAFFL", "EOSSTT"),
  names(adsl)
)

adsl_arm_choices <- choices_selected(
  choices = variable_choices(adsl, arm_vars),
  selected = "ACTARM"
)
demog_vars_choices <- choices_selected(
  choices = variable_choices(adsl, demog_summary_vars),
  selected = c("AGE", "AGEGR1", "SEX", "RACE")
)

adae_arm_choices <- choices_selected(
  choices = variable_choices(adae, intersect(arm_vars, names(adae))),
  selected = if ("ACTARM" %in% names(adae)) "ACTARM" else arm_vars[1]
)
adae_hlt_choices <- choices_selected(
  choices = variable_choices(adae, "AEBODSYS"),
  selected = "AEBODSYS"
)
adae_llt_choices <- choices_selected(
  choices = variable_choices(adae, "AEDECOD"),
  selected = "AEDECOD"
)

# ---- Assemble the app --------------------------------------------------------
app <- init(
  data = data,
  modules = modules(
    tm_variable_browser(
      label = "Variable browser",
      datanames = c("ADSL", "ADAE")
    ),
    tm_data_table(
      label = "Data table",
      datanames = c("ADSL", "ADAE")
    ),
    tm_t_summary(
      label = "Demographics table",
      dataname = "ADSL",
      arm_var = adsl_arm_choices,
      summarize_vars = demog_vars_choices
    ),
    tm_t_events(
      label = "Adverse events table",
      dataname = "ADAE",
      arm_var = adae_arm_choices,
      hlt = adae_hlt_choices,
      llt = adae_llt_choices
    )
  ),
  filter = teal_slices(
    teal_slice(dataname = "ADSL", varname = "ACTARM"),
    teal_slice(dataname = "ADSL", varname = "SEX"),
    teal_slice(dataname = "ADSL", varname = "AGE")
  )
)

shinyApp(app$ui, app$server)
