# Interactive teal app

An interactive companion to the [pipeline report](../pipeline_report.qmd): a
[`{teal}`](https://insightsengineering.github.io/teal/) Shiny app for
exploring the pipeline's ADSL/ADAE data, with a global filter panel (arm,
sex, age, ...) shared across every module.

## Modules

| Module | Package | What it shows |
|---|---|---|
| Variable browser | `{teal.modules.general}` | Per-variable summary stats/distribution for ADSL and ADAE |
| Data table | `{teal.modules.general}` | Searchable/sortable ADSL and ADAE listings |
| Demographics table | `{teal.modules.clinical}` | Interactive version of the Demographics table (age, age group, sex, race by arm) |
| Adverse events table | `{teal.modules.clinical}` | Interactive version of the Adverse Events table, by System Organ Class / Preferred Term |

## Data

`data/adsl.rds` and `data/adae.rds` are the `{pharmaverseadam}` reference
`ADSL`/`ADAE` (same choice as `scripts/06_tlg_adverse_events.R` and
`scripts/08_tlg_plots.R` in the parent project) -- the abbreviated
`safety_specs.xlsx` spec used to derive `ADAE` in `scripts/04_adam_adae.R`
doesn't carry the MedDRA hierarchy variables (`AEBODSYS`/`AEDECOD`/etc.) the
Adverse Events table needs. The app directory is self-contained (data is
copied in locally) so it can be deployed on its own.

## Run locally

```r
shiny::runApp("teal_app")
```

or open `app.R` in Positron/RStudio and click **Run App**.

## Deploy

### Posit Connect Cloud

```r
library(rsconnect)
connectCloudUser()          # one-time browser authentication
deployApp(
  appDir = "teal_app",
  appTitle = "pharmaverse pipeline explorer"
)
```

### A traditional/self-hosted Posit Connect server

```r
library(rsconnect)
# One-time setup, using either an API key or interactive login:
connectApiUser(account = "<your-account>", server = "<your-connect-server>", apiKey = "<api-key>")
# or: connectUser(server = "<your-connect-server>")

deployApp(
  appDir = "teal_app",
  appTitle = "pharmaverse pipeline explorer",
  server = "<your-connect-server>"
)
```

`rsconnect::deployApp()` auto-detects the required R packages from
`app.R` -- no manifest or lockfile is required for this app directory.
