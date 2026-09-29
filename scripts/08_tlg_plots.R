# ============================================================================
# TLG: Supporting plots for the Demographics and Adverse Events analyses
# Companion graphics to the tables in scripts 05/06, built with {ggplot2} on
# the same ADaM inputs (ADSL from this pipeline; ADSL/ADAE from
# {pharmaverseadam} for the AE plot, for the same reason as script 06 --
# see AGENTS.md).
# ============================================================================

library(dplyr)
library(ggplot2)
library(scales)
library(pharmaverseadam)

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

# ---- Plot 1: Age distribution by treatment arm -----------------------------
adsl <- readRDS("data/adam_adsl.rds") %>%
  filter(!ACTARM %in% "Screen Failure")

p_age <- ggplot(adsl, aes(x = ACTARM, y = AGE)) +
  geom_boxplot(width = 0.5, outlier.shape = NA) +
  geom_jitter(width = 0.15, alpha = 0.4, size = 1.5) +
  labs(
    title = "Age Distribution by Treatment Arm",
    subtitle = "ADSL, Safety Population",
    x = NULL, y = "Age (years)"
  ) +
  theme_minimal(base_size = 12)

ggsave("output/figures/age_by_arm.png", p_age, width = 8, height = 5, dpi = 150)

# ---- Plot 2: AE incidence (% of patients) by System Organ Class -----------
adsl_ae <- pharmaverseadam::adsl %>% filter(SAFFL == "Y")
adae <- pharmaverseadam::adae %>% filter(SAFFL == "Y")

n_by_arm <- adsl_ae %>%
  count(ACTARM, name = "n_subj")

# Restrict to the SOCs with the highest overall incidence for readability
top_soc <- adae %>%
  distinct(USUBJID, AEBODSYS) %>%
  count(AEBODSYS, name = "n") %>%
  slice_max(n, n = 10) %>%
  pull(AEBODSYS)

ae_soc_pct <- adae %>%
  filter(AEBODSYS %in% top_soc) %>%
  distinct(USUBJID, ACTARM, AEBODSYS) %>%
  count(ACTARM, AEBODSYS, name = "n_pts") %>%
  left_join(n_by_arm, by = "ACTARM") %>%
  mutate(pct = n_pts / n_subj)

p_ae_soc <- ggplot(
  ae_soc_pct,
  aes(x = pct, y = reorder(AEBODSYS, pct), fill = ACTARM)
) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_x_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Adverse Event Incidence by System Organ Class",
    subtitle = "Top 10 SOCs by overall incidence, Safety Population",
    x = "% of patients with >= 1 event", y = NULL, fill = "Treatment"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave("output/figures/ae_incidence_by_soc.png", p_ae_soc, width = 9, height = 6, dpi = 150)

# ---- Combine into a single multi-page PDF ----------------------------------
pdf("output/figures.pdf", width = 9, height = 6)
print(p_age)
print(p_ae_soc)
dev.off()

cat("Wrote output/figures/age_by_arm.png, output/figures/ae_incidence_by_soc.png, output/figures.pdf\n")
