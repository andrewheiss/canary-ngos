library(targets)
library(tarchetypes)
library(tibble)

# General variables
csl <- "pandoc/csl/chicago-author-date.csl"
bibstyle <- "bibstyle-chicago-authordate"

suppressPackageStartupMessages(library(brms))


# Bayes-specific stuff
options(mc.cores = 4,
        brms.backend = "cmdstanr")

options(tidyverse.quiet = TRUE,
        dplyr.summarise.inform = FALSE)

# By default, R uses polynomial contrasts for ordered factors in linear models
# options("contrasts")
# So make ordered factors use treatment contrasts instead
options(contrasts = rep("contr.treatment", 2))
# Or do it on a single variable:
# contrasts(df$x) <- "contr.treatment"

# Things that get set in options() are not passed down to workers in future (see
# https://github.com/HenrikBengtsson/future/issues/134), which means all these
# neat options we set here disappear when running tar_make_future() (like
# ordered treatment contrasts and the number of cores used, etc.). The official
# recommendation is to add options() calls to the individual workers.
#
# We do this by including options() in the functions where we define model
# priors and other settings (i.e. pts_settings()). But setting options there
# inside a bunch of files can get tedious, since the number of cores, workers,
# etc. depends on the computer we run this on (i.e. my 4-core personal laptop
# vs. my 16-core work laptop).

# Pass these options to workers using options(worker_options)
worker_options <- options()[c("mc.cores", "brms.backend",
                              "contrasts", "tidyverse.quiet",
                              "dplyr.summarise.inform")]

set.seed(9936)  # From random.org

future::plan(future::multisession)

tar_option_set(packages = c("tidyverse", "countrycode", "states", "WDI", "here", "fs",
                            "readxl", "haven", "sf", "lubridate", "scales",
                            "janitor", "kableExtra", "huxtable", "modelsummary",
                            "knitr", "withr", "flextable", "testthat", "DT",
                            "brms", "tidybayes", "broom", "cmdstanr", "jsonlite"))

source("R/funs_data-cleaning.R")
source("R/funs_knitting.R")
source("R/funs_notebook.R")
source("R/models_details.R")
source("R/models_analysis.R")
source("R/models_pts.R")
source("R/models_clphy.R")
source("R/models_clpriv.R")
source("R/models_lhr.R")

# here::here() returns an absolute path, which then gets stored in tar_meta and
# becomes computer-specific (i.e. /Users/andrew/Research/blah/thing.Rmd).
# There's no way to get a relative path directly out of here::here(), but
# fs::path_rel() works fine with it (see
# https://github.com/r-lib/here/issues/36#issuecomment-530894167)
here_rel <- function(...) {fs::path_rel(here::here(...))}


list(
  # Define raw data files
  tar_target(chaudhry_raw_file,
             here_rel("data", "raw_data", "Chaudhry restrictions", "SC_Expanded.dta"),
             format = "file"),
  tar_target(pts_raw_file,
             here_rel("data", "raw_data", "Political Terror Scale", "PTS-2019.RData"),
             format = "file"),
  tar_target(latent_hr_raw_file,
             here_rel("data", "raw_data", "Latent Human Rights Protection Scores",
                      "HumanRightsProtectionScores_v4.01.csv"),
             format = "file"),
  tar_target(journalists_raw_file,
             here_rel("data", "raw_data", "Gohdes Carey journalists",
                  "journalist-data-incl-pts.RData"),
             format = "file"),
  tar_target(ucdp_raw_file,
             here_rel("data", "raw_data", "UCDP PRIO", "ucdp-prio-acd-191.csv"),
             format = "file"),
  tar_target(vdem_raw_file,
             here_rel("data", "raw_data", "Country_Year_V-Dem_Full+others_R_v10",
                  "V-Dem-CY-Full+Others-v10.rds"),
             format = "file"),
  tar_target(un_pop_raw_file,
             here_rel("data", "raw_data", "UN data",
                  "WPP2019_POP_F01_1_TOTAL_POPULATION_BOTH_SEXES.xlsx"),
             format = "file"),
  tar_target(un_gdp_constant_raw_file,
             here_rel("data", "raw_data", "UN data",
                  "UNdata_Export_20210118_034054729.csv"),
             format = "file"),
  tar_target(un_gdp_current_raw_file,
             here_rel("data", "raw_data", "UN data",
                  "UNdata_Export_20210118_034311252.csv"),
             format = "file"),
  tar_target(naturalearth_raw_file,
             here_rel("data", "raw_data", "ne_110m_admin_0_countries",
                      "ne_110m_admin_0_countries.shp"),
             format = "file"),
  tar_target(civicus_raw_file,
             here_rel("data", "raw_data", "Civicus", "civicus_2021-03-19.json"),
             format = "file"),

  # Define helper functions
  tar_target(plot_funs, here_rel("lib", "graphics.R"), format = "file"),

  # Load and clean data
  tar_target(world_map, load_world_map(naturalearth_raw_file)),
  tar_target(civicus_clean, load_clean_civicus(civicus_raw_file)),
  tar_target(civicus_map_data, create_civicus_map_data(civicus_clean, world_map)),

  tar_target(skeleton, create_panel_skeleton()),
  tar_target(wdi_clean, load_clean_wdi(skeleton)),
  tar_target(chaudhry_clean, load_clean_chaudhry(chaudhry_raw_file)),
  tar_target(pts_clean, load_clean_pts(pts_raw_file, skeleton)),
  tar_target(latent_hr_clean, load_clean_latent_hr(latent_hr_raw_file, skeleton)),
  tar_target(killings_all, load_clean_journalists(journalists_raw_file)),
  tar_target(ucdp_prio_clean, load_clean_ucdp(ucdp_raw_file)),
  tar_target(vdem_clean, load_clean_vdem(vdem_raw_file)),
  tar_target(un_pop, load_clean_un_pop(un_pop_raw_file, skeleton, wdi_clean)),
  tar_target(un_gdp, load_clean_un_gdp(un_gdp_constant_raw_file,
                                       un_gdp_current_raw_file, skeleton)),
  # Combine data
  # This includes 2014 for lagging/leading
  tar_target(panel_with_2014, combine_data(skeleton, chaudhry_clean,
                                           pts_clean, latent_hr_clean, killings_all,
                                           ucdp_prio_clean, vdem_clean,
                                           un_pop, un_gdp)),
  # THIS is the final 2014-less data
  tar_target(panel, trim_data(panel_with_2014)),

  # Lagging/leading
  tar_target(panel_lagged, trim_data(lag_data(panel_with_2014))),

  # Training/testing
  tar_target(panel_training, trim_data(create_training(panel_with_2014))),  # Remove 2014
  tar_target(panel_training_lagged, create_training(panel_lagged)),
  tar_target(panel_testing, trim_data(create_testing(panel_with_2014))),  # Remove 2014
  tar_target(panel_testing_lagged, create_testing(panel_lagged)),

  # Models for the political terror score (PTS_factor)
  ## Models using full data
  tar_target(m_pts_baseline, f_pts_baseline(panel_lagged)),
  tar_target(m_pts_total, f_pts_total(panel_lagged)),
  tar_target(m_pts_total_new, f_pts_total_new(panel_lagged)),
  tar_target(m_pts_advocacy, f_pts_advocacy(panel_lagged)),
  tar_target(m_pts_entry, f_pts_entry(panel_lagged)),
  tar_target(m_pts_funding, f_pts_funding(panel_lagged)),
  tar_target(m_pts_v2csreprss, f_pts_v2csreprss(panel_lagged)),

  tar_target(m_pts_baseline_rewb, f_pts_baseline_rewb(panel_lagged)),
  tar_target(m_pts_total_rewb, f_pts_total_rewb(panel_lagged)),
  tar_target(m_pts_advocacy_rewb, f_pts_advocacy_rewb(panel_lagged)),
  tar_target(m_pts_entry_rewb, f_pts_entry_rewb(panel_lagged)),
  tar_target(m_pts_funding_rewb, f_pts_funding_rewb(panel_lagged)),
  tar_target(m_pts_v2csreprss_rewb, f_pts_v2csreprss_rewb(panel_lagged)),

  ## Models using training data
  tar_target(m_pts_baseline_train, f_pts_baseline(panel_training_lagged)),
  tar_target(m_pts_total_train, f_pts_total(panel_training_lagged)),
  tar_target(m_pts_advocacy_train, f_pts_advocacy(panel_training_lagged)),
  tar_target(m_pts_entry_train, f_pts_entry(panel_training_lagged)),
  tar_target(m_pts_funding_train, f_pts_funding(panel_training_lagged)),
  tar_target(m_pts_v2csreprss_train, f_pts_v2csreprss(panel_training_lagged)),

  tar_target(m_pts_baseline_rewb_train, f_pts_baseline_rewb(panel_training_lagged)),
  tar_target(m_pts_total_rewb_train, f_pts_total_rewb(panel_training_lagged)),
  tar_target(m_pts_advocacy_rewb_train, f_pts_advocacy_rewb(panel_training_lagged)),
  tar_target(m_pts_entry_rewb_train, f_pts_entry_rewb(panel_training_lagged)),
  tar_target(m_pts_funding_rewb_train, f_pts_funding_rewb(panel_training_lagged)),
  tar_target(m_pts_v2csreprss_rewb_train, f_pts_v2csreprss_rewb(panel_training_lagged)),

  # Models for physical violence (v2x_clphy)
  ## Models using full data
  tar_target(m_clphy_baseline, f_clphy_baseline(panel_lagged)),
  tar_target(m_clphy_total, f_clphy_total(panel_lagged)),
  tar_target(m_clphy_total_new, f_clphy_total_new(panel_lagged)),
  tar_target(m_clphy_advocacy, f_clphy_advocacy(panel_lagged)),
  tar_target(m_clphy_entry, f_clphy_entry(panel_lagged)),
  tar_target(m_clphy_funding, f_clphy_funding(panel_lagged)),
  tar_target(m_clphy_v2csreprss, f_clphy_v2csreprss(panel_lagged)),

  tar_target(m_clphy_baseline_rewb, f_clphy_baseline_rewb(panel_lagged)),
  tar_target(m_clphy_total_rewb, f_clphy_total_rewb(panel_lagged)),
  tar_target(m_clphy_advocacy_rewb, f_clphy_advocacy_rewb(panel_lagged)),
  tar_target(m_clphy_entry_rewb, f_clphy_entry_rewb(panel_lagged)),
  tar_target(m_clphy_funding_rewb, f_clphy_funding_rewb(panel_lagged)),
  tar_target(m_clphy_v2csreprss_rewb, f_clphy_v2csreprss_rewb(panel_lagged)),

  ## Models using training data
  tar_target(m_clphy_baseline_train, f_clphy_baseline(panel_training_lagged)),
  tar_target(m_clphy_total_train, f_clphy_total(panel_training_lagged)),
  tar_target(m_clphy_advocacy_train, f_clphy_advocacy(panel_training_lagged)),
  tar_target(m_clphy_entry_train, f_clphy_entry(panel_training_lagged)),
  tar_target(m_clphy_funding_train, f_clphy_funding(panel_training_lagged)),
  tar_target(m_clphy_v2csreprss_train, f_clphy_v2csreprss(panel_training_lagged)),

  tar_target(m_clphy_baseline_rewb_train, f_clphy_baseline_rewb(panel_training_lagged)),
  tar_target(m_clphy_total_rewb_train, f_clphy_total_rewb(panel_training_lagged)),
  tar_target(m_clphy_advocacy_rewb_train, f_clphy_advocacy_rewb(panel_training_lagged)),
  tar_target(m_clphy_entry_rewb_train, f_clphy_entry_rewb(panel_training_lagged)),
  tar_target(m_clphy_funding_rewb_train, f_clphy_funding_rewb(panel_training_lagged)),
  tar_target(m_clphy_v2csreprss_rewb_train, f_clphy_v2csreprss_rewb(panel_training_lagged)),

  # Models for private civil liberties (v2x_clpriv)
  ## Models using full data
  tar_target(m_clpriv_baseline, f_clpriv_baseline(panel_lagged)),
  tar_target(m_clpriv_total, f_clpriv_total(panel_lagged)),
  tar_target(m_clpriv_total_new, f_clpriv_total_new(panel_lagged)),
  tar_target(m_clpriv_advocacy, f_clpriv_advocacy(panel_lagged)),
  tar_target(m_clpriv_entry, f_clpriv_entry(panel_lagged)),
  tar_target(m_clpriv_funding, f_clpriv_funding(panel_lagged)),
  tar_target(m_clpriv_v2csreprss, f_clpriv_v2csreprss(panel_lagged)),

  tar_target(m_clpriv_baseline_rewb, f_clpriv_baseline_rewb(panel_lagged)),
  tar_target(m_clpriv_total_rewb, f_clpriv_total_rewb(panel_lagged)),
  tar_target(m_clpriv_advocacy_rewb, f_clpriv_advocacy_rewb(panel_lagged)),
  tar_target(m_clpriv_entry_rewb, f_clpriv_entry_rewb(panel_lagged)),
  tar_target(m_clpriv_funding_rewb, f_clpriv_funding_rewb(panel_lagged)),
  tar_target(m_clpriv_v2csreprss_rewb, f_clpriv_v2csreprss_rewb(panel_lagged)),

  ## Models using training data
  tar_target(m_clpriv_baseline_train, f_clpriv_baseline(panel_training_lagged)),
  tar_target(m_clpriv_total_train, f_clpriv_total(panel_training_lagged)),
  tar_target(m_clpriv_advocacy_train, f_clpriv_advocacy(panel_training_lagged)),
  tar_target(m_clpriv_entry_train, f_clpriv_entry(panel_training_lagged)),
  tar_target(m_clpriv_funding_train, f_clpriv_funding(panel_training_lagged)),
  tar_target(m_clpriv_v2csreprss_train, f_clpriv_v2csreprss(panel_training_lagged)),

  tar_target(m_clpriv_baseline_rewb_train, f_clpriv_baseline_rewb(panel_training_lagged)),
  tar_target(m_clpriv_total_rewb_train, f_clpriv_total_rewb(panel_training_lagged)),
  tar_target(m_clpriv_advocacy_rewb_train, f_clpriv_advocacy_rewb(panel_training_lagged)),
  tar_target(m_clpriv_entry_rewb_train, f_clpriv_entry_rewb(panel_training_lagged)),
  tar_target(m_clpriv_funding_rewb_train, f_clpriv_funding_rewb(panel_training_lagged)),
  tar_target(m_clpriv_v2csreprss_rewb_train, f_clpriv_v2csreprss_rewb(panel_training_lagged)),

  # Models for latent respect for human rights (latent_hr_mean)
  ## Models using full data
  tar_target(m_lhr_baseline, f_lhr_baseline(panel_lagged)),
  tar_target(m_lhr_total, f_lhr_total(panel_lagged)),
  tar_target(m_lhr_total_new, f_lhr_total_new(panel_lagged)),
  tar_target(m_lhr_advocacy, f_lhr_advocacy(panel_lagged)),
  tar_target(m_lhr_entry, f_lhr_entry(panel_lagged)),
  tar_target(m_lhr_funding, f_lhr_funding(panel_lagged)),
  tar_target(m_lhr_v2csreprss, f_lhr_v2csreprss(panel_lagged)),

  tar_target(m_lhr_baseline_train, f_lhr_baseline(panel_training_lagged)),
  tar_target(m_lhr_total_train, f_lhr_total(panel_training_lagged)),
  tar_target(m_lhr_total_new_train, f_lhr_total_new(panel_training_lagged)),
  tar_target(m_lhr_advocacy_train, f_lhr_advocacy(panel_training_lagged)),
  tar_target(m_lhr_entry_train, f_lhr_entry(panel_training_lagged)),
  tar_target(m_lhr_funding_train, f_lhr_funding(panel_training_lagged)),
  tar_target(m_lhr_v2csreprss_train, f_lhr_v2csreprss(panel_training_lagged)),

  # Big dataframe of model names for full models
  tar_target(model_df, create_model_df()),

  # Calculate marginal effects
  tar_target(mfx_e1a_pts, generate_mfx(
    tibble(model = list(m_pts_total, m_pts_advocacy, m_pts_entry, m_pts_funding),
           plot_var = c("barriers_total", "advocacy", "entry", "funding"),
           plot_var_nice = c("Total legal barriers", "Barriers to advocacy",
                             "Barriers to entry", "Barriers to funding")),
    is_categorical = TRUE)),

  tar_target(mfx_e1b_clphy, generate_mfx(
    tibble(model = list(m_clphy_total, m_clphy_advocacy, m_clphy_entry, m_clphy_funding),
           plot_var = c("barriers_total", "advocacy", "entry", "funding"),
           plot_var_nice = c("Total legal barriers", "Barriers to advocacy",
                             "Barriers to entry", "Barriers to funding")))),

  tar_target(mfx_e1c_clpriv, generate_mfx(
    tibble(model = list(m_clpriv_total, m_clpriv_advocacy, m_clpriv_entry, m_clpriv_funding),
           plot_var = c("barriers_total", "advocacy", "entry", "funding"),
           plot_var_nice = c("Total legal barriers", "Barriers to advocacy",
                             "Barriers to entry", "Barriers to funding")))),

  tar_target(mfx_e1d_lhr, generate_mfx(
    tibble(model = list(m_lhr_total, m_lhr_advocacy, m_lhr_entry, m_lhr_funding),
           plot_var = c("barriers_total", "advocacy", "entry", "funding"),
           plot_var_nice = c("Total legal barriers", "Barriers to advocacy",
                             "Barriers to entry", "Barriers to funding")))),

  tar_target(mfx_e2a_pts, generate_mfx(
    tibble(model = list(m_pts_v2csreprss),
           plot_var = c("v2csreprss"),
           plot_var_nice = c("Civil society repression")),
    is_categorical = TRUE)),

  tar_target(mfx_e2b_clphy, generate_mfx(
    tibble(model = list(m_clphy_v2csreprss),
           plot_var = c("v2csreprss"),
           plot_var_nice = c("Civil society repression")))),

  tar_target(mfx_e2c_clpriv, generate_mfx(
    tibble(model = list(m_clpriv_v2csreprss),
           plot_var = c("v2csreprss"),
           plot_var_nice = c("Civil society repression")))),

  tar_target(mfx_e2d_lhr, generate_mfx(
    tibble(model = list(m_lhr_v2csreprss),
           plot_var = c("v2csreprss"),
           plot_var_nice = c("Civil society repression")))),

  # Build models here because they take forever
  # Note tibble::lst() instead of base::list(); lst() auto-names the elements by
  # their object names
  tar_target(coef_list, build_coef_list()),

  # Expectation 1
  tar_target(models_tbl_e1a_re,
             build_modelsummary(lst(m_pts_baseline, m_pts_total, m_pts_total_new,
                                    m_pts_advocacy, m_pts_entry,
                                    m_pts_funding))),
  tar_target(models_tbl_e1a_rewb,
             build_modelsummary(lst(m_pts_baseline_rewb, m_pts_total_rewb,
                                    m_pts_advocacy_rewb, m_pts_entry_rewb,
                                    m_pts_funding_rewb))),
  tar_target(models_tbl_e1b_re,
             build_modelsummary(lst(m_clphy_baseline, m_clphy_total, m_clphy_total_new,
                                    m_clphy_advocacy, m_clphy_entry,
                                    m_clphy_funding))),
  tar_target(models_tbl_e1c_re,
             build_modelsummary(lst(m_clpriv_baseline, m_clpriv_total, m_clpriv_total_new,
                                    m_clpriv_advocacy, m_clpriv_entry,
                                    m_clpriv_funding))),
  tar_target(models_tbl_e1d_re,
             build_modelsummary(lst(m_lhr_baseline, m_lhr_total, m_lhr_total_new,
                                    m_lhr_advocacy, m_lhr_entry,
                                    m_lhr_funding))),
  # Expectation 2
  tar_target(models_tbl_e2a,
             build_modelsummary(lst(m_pts_baseline, m_pts_v2csreprss,
                                    m_pts_baseline_rewb, m_pts_v2csreprss_rewb))),
  tar_target(models_tbl_e2b,
             build_modelsummary(lst(m_clphy_baseline, m_clphy_v2csreprss,
                                    m_clphy_baseline_rewb, m_clphy_v2csreprss_rewb))),
  tar_target(models_tbl_e2c,
             build_modelsummary(lst(m_clpriv_baseline, m_clpriv_v2csreprss,
                                    m_clpriv_baseline_rewb, m_clpriv_v2csreprss_rewb))),
  tar_target(models_tbl_e2d,
             build_modelsummary(lst(m_lhr_baseline, m_lhr_v2csreprss))),

  # Models for paper
  tar_target(models_paper_pts,
             build_modelsummary(lst(m_pts_total, m_pts_advocacy, m_pts_entry,
                                    m_pts_funding, m_pts_v2csreprss))),
  tar_target(models_paper_clphy,
             build_modelsummary(lst(m_clphy_total, m_clphy_advocacy, m_clphy_entry,
                                    m_clphy_funding, m_clphy_v2csreprss))),
  tar_target(models_paper_clpriv,
             build_modelsummary(lst(m_clpriv_total, m_clpriv_advocacy, m_clpriv_entry,
                                    m_clpriv_funding, m_clpriv_v2csreprss))),
  tar_target(models_paper_lhr,
             build_modelsummary(lst(m_lhr_total, m_lhr_advocacy, m_lhr_entry,
                                    m_lhr_funding, m_lhr_v2csreprss))),

  # Render the analysis notebook
  tar_notebook_pages(),

  # tarchetypes::tar_render() automatically detects target dependencies in Rmd
  # files and knits them, but there's no easy way to pass a custom rendering
  # script like bookdown::html_document2(), so two things happen here:
  #   1. Set a file-based target with tar_target_raw() and use tar_knitr_deps()
  #      to detect the target dependencies in the Rmd file
  #   2. Use a bunch of other file-based targets to actually render the document
  #      through different custom functions
  tar_target(bib_file,
             here_rel("manuscript", "bibliography.bib"),
             format = "file"),

  tar_target_raw("main_manuscript", here_rel("manuscript", "manuscript.Rmd"),
                 format = "file",
                 deps = c("bib_file",
                          tar_knitr_deps(here_rel("manuscript", "manuscript.Rmd")))),
  tar_target(html,
             render_html(
               input = main_manuscript,
               output = here_rel("manuscript", "output", "manuscript.html"),
               csl = csl,
               bib_file,
               support_folder = "output/html-support"),
             format = "file"),
  tar_target(pdf,
             render_pdf(
               input = main_manuscript,
               output = here_rel("manuscript", "output/manuscript.pdf"),
               bibstyle = bibstyle,
               bib_file),
             format = "file"),
  tar_target(ms_pdf,
             render_pdf_ms(
               input = main_manuscript,
               output = here_rel("manuscript", "output/manuscript-ms.pdf"),
               bibstyle = bibstyle,
               bib_file),
             format = "file"),
  tar_target(docx,
             render_docx(
               input = main_manuscript,
               output = here_rel("manuscript", "output/manuscript.docx"),
               csl = csl,
               bib_file),
             format = "file"),
  tar_target(bib,
             extract_bib(
               input_rmd = main_manuscript,
               input_bib = bib_file,
               output = here_rel("manuscript", "output", "extracted-citations.bib")),
             format = "file")
)
