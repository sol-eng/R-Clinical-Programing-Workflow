# ============================================================================
# TLG: PDF export of the Demographic and Adverse Events tables
# Uses {rtables}/{formatters} export_as_pdf() on the TableTree objects built
# in scripts 05/06.
# ============================================================================

library(rtables)

if (!exists("demographic_table")) source("scripts/05_tlg_demographic.R")
if (!exists("adverse_events_table")) source("scripts/06_tlg_adverse_events.R")

dir.create("output", showWarnings = FALSE)

# ---- Demographic table: fits comfortably on one landscape letter page -----
export_as_pdf(
  demographic_table,
  file = "output/demographic_table.pdf",
  page_type = "letter",
  landscape = TRUE,
  font_size = 9,
  margins = c(2, 2, 2, 2)
)

# ---- Adverse Events table: long, nested by SOC/PT -> paginates across ----
# multiple landscape pages. rtables keeps each SOC's PT rows from splitting
# across a page boundary (min_siblings), which can trigger benign "height
# exceeds available space" warnings on a handful of pages -- the PDF itself
# is still complete and correctly paginated.
export_as_pdf(
  adverse_events_table,
  file = "output/adverse_events_table.pdf",
  page_type = "letter",
  landscape = TRUE,
  font_size = 8,
  margins = c(2, 2, 2, 2)
)

cat("Wrote output/demographic_table.pdf and output/adverse_events_table.pdf\n")
