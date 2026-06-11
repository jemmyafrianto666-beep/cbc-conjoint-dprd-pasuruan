# =========================================================
# SCRIPT ANALISIS CHOICE-BASED CONJOINT
# Judul: Faktor Penentu Kemenangan Kandidat DPRD
# =========================================================
# Script ini digunakan untuk:
# 1. Membuat profile dan design CBC
# 2. Mengimpor data long
# 3. Memeriksa struktur data
# 4. Mengestimasi AMCE
# 5. Membuat tabel dan grafik AMCE

rm(list = ls())
graphics.off()

# =========================================================
# 1. INSTALL DAN PANGGIL PACKAGE
# =========================================================

paket_cran <- c(
  "dplyr", "readr", "readxl", "stringr", "fixest",
  "ggplot2", "tibble", "writexl"
)

for (p in paket_cran) {
  if (!requireNamespace(p, quietly = TRUE)) {
    install.packages(p, dependencies = TRUE)
  }
  library(p, character.only = TRUE)
}

if (!requireNamespace("cbcTools", quietly = TRUE)) {
  if (!requireNamespace("remotes", quietly = TRUE)) {
    install.packages("remotes", dependencies = TRUE)
  }
  remotes::install_github("jhelvy/cbcTools")
}
library(cbcTools)

# =========================================================
# 2. TENTUKAN FOLDER PENYIMPANAN
# =========================================================
# Output akan disimpan di folder "output_cbc" pada working directory aktif.
# Untuk mengubah lokasi penyimpanan, ganti bagian folder_simpan di bawah ini.

folder_simpan <- file.path(getwd(), "output_cbc")

folder_data <- file.path(folder_simpan, "data")
folder_design <- file.path(folder_simpan, "design")
folder_output <- file.path(folder_simpan, "output")
folder_grafik <- file.path(folder_simpan, "grafik")
folder_model <- file.path(folder_simpan, "model")

for (f in c(folder_simpan, folder_data, folder_design, folder_output, folder_grafik, folder_model)) {
  dir.create(f, recursive = TRUE, showWarnings = FALSE)
}

# =========================================================
# 3. MEMBUAT PROFIL ATRIBUT CBC
# =========================================================

profiles <- cbc_profiles(
  Gender = c("Laki_laki", "Perempuan"),
  Usia_Tampak = c("35_45", "45_55"),
  Tone_Kulit = c("Cerah", "Sawo_Matang"),
  Fitur_Wajah = c("Ramah_Lembut", "Tegas_Berwibawa"),
  Gaya_Berpakaian = c("Formal_Rapi", "Religius_Tradisional"),
  Pendidikan = c("S1_Ke_Bawah", "S2_S3"),
  Ketokohan = c("Tokoh_Masyarakat_Lokal", "Belum_Tokoh_Publik"),
  Pengalaman_Militer = c("Ada_Militer", "Tidak_Ada_Militer")
)

profiles_df <- as.data.frame(profiles) %>%
  as_tibble() %>%
  mutate(Profile_ID = row_number(), .before = 1)

write.csv2(profiles_df, file.path(folder_design, "cbc_profiles_final.csv"), row.names = FALSE)
saveRDS(profiles, file.path(folder_model, "cbc_profiles_final.rds"))

# =========================================================
# 4. MEMBUAT DESAIN CBC
# =========================================================

set.seed(2025)

design <- cbc_design(
  profiles = profiles,
  n_alts = 2,
  n_q = 8,
  n_resp = 1,
  method = "balanced",
  no_choice = FALSE,
  randomize_questions = FALSE,
  randomize_alts = FALSE
)

inspect_basic <- cbc_inspect(
  design,
  sections = c("structure", "balance", "overlap")
)

design_df <- as.data.frame(design) %>% as_tibble()

write.csv2(design_df, file.path(folder_design, "cbc_design_final.csv"), row.names = FALSE)

sink(file.path(folder_design, "cbc_inspect_final.txt"))
print(inspect_basic)
sink()

sink(file.path(folder_design, "citation_cbcTools.txt"))
print(citation("cbcTools"))
sink()

saveRDS(design, file.path(folder_model, "cbc_design_final.rds"))
saveRDS(inspect_basic, file.path(folder_model, "cbc_inspect_final.rds"))

# =========================================================
# 5. IMPORT DATA LONG
# =========================================================

file_data <- file.choose()

baca_data <- function(file_path) {
  ext <- tolower(tools::file_ext(file_path))

  if (ext == "rds") {
    data <- readRDS(file_path)
  } else if (ext %in% c("xlsx", "xls")) {
    data <- readxl::read_excel(file_path)
    data <- as.data.frame(data)
  } else if (ext == "csv") {
    data <- read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)
    if (ncol(data) == 1) {
      data <- read.csv2(file_path, stringsAsFactors = FALSE, check.names = FALSE)
    }
  } else {
    stop("Format file belum didukung. Gunakan .csv, .xlsx, .xls, atau .rds")
  }

  return(data)
}

data_long <- baca_data(file_data)

names(data_long) <- names(data_long) %>%
  stringr::str_trim() %>%
  stringr::str_replace_all("\\s+", "_")

# Jika choice_id belum unik per responden, buat ulang dari Responden_ID dan choice_id asli.
if ("choice_id" %in% names(data_long)) {
  data_long <- data_long %>%
    mutate(choice_id_raw = choice_id)

  cek_choice_sementara <- data_long %>%
    count(choice_id, name = "jumlah_baris")

  if (any(cek_choice_sementara$jumlah_baris != 2)) {
    data_long <- data_long %>%
      mutate(choice_id = paste(Responden_ID, choice_id_raw, sep = "_"))
  }
}

write.csv2(data_long, file.path(folder_data, "data_long_imported.csv"), row.names = FALSE)

# =========================================================
# 6. CEK STRUKTUR DATA
# =========================================================

kolom_wajib <- c(
  "Responden_ID", "choice_id", "Chosen",
  "Gender", "Usia_Tampak", "Tone_Kulit", "Fitur_Wajah",
  "Gaya_Berpakaian", "Pendidikan", "Ketokohan", "Pengalaman_Militer"
)

kolom_hilang <- setdiff(kolom_wajib, names(data_long))

if (length(kolom_hilang) > 0) {
  stop(paste("Kolom berikut belum ditemukan:", paste(kolom_hilang, collapse = ", ")))
}

data_long <- data_long %>%
  mutate(
    Chosen = as.character(Chosen),
    Chosen = case_when(
      Chosen %in% c("1", "Ya", "ya", "TRUE", "True", "true", "Dipilih", "dipilih") ~ 1,
      Chosen %in% c("0", "Tidak", "tidak", "FALSE", "False", "false", "Tidak dipilih", "tidak dipilih") ~ 0,
      TRUE ~ suppressWarnings(as.numeric(Chosen))
    )
  )

cek_jumlah_responden <- data_long %>%
  summarise(jumlah_responden = n_distinct(Responden_ID))

cek_baris_responden <- data_long %>%
  count(Responden_ID, name = "jumlah_baris") %>%
  summarise(
    min_baris = min(jumlah_baris),
    max_baris = max(jumlah_baris),
    rata_baris = mean(jumlah_baris)
  )

cek_baris_choice <- data_long %>%
  count(choice_id, name = "jumlah_baris") %>%
  summarise(
    min_baris = min(jumlah_baris),
    max_baris = max(jumlah_baris)
  )

cek_pilihan <- data_long %>%
  group_by(choice_id) %>%
  summarise(jumlah_terpilih = sum(Chosen, na.rm = TRUE), .groups = "drop") %>%
  count(jumlah_terpilih, name = "jumlah_choice_set")

if ("Dapil" %in% names(data_long)) {
  cek_dapil <- data_long %>%
    distinct(Responden_ID, Dapil) %>%
    count(Dapil, name = "jumlah_responden")
} else {
  cek_dapil <- tibble(keterangan = "Kolom Dapil tidak tersedia")
}

print(cek_jumlah_responden)
print(cek_baris_responden)
print(cek_baris_choice)
print(cek_pilihan)
print(cek_dapil)

writexl::write_xlsx(
  list(
    "Jumlah Responden" = cek_jumlah_responden,
    "Baris per Responden" = cek_baris_responden,
    "Baris per Choice ID" = cek_baris_choice,
    "Validasi Pilihan" = cek_pilihan,
    "Responden per Dapil" = cek_dapil
  ),
  file.path(folder_output, "pemeriksaan_struktur_data_long.xlsx")
)

if (cek_baris_choice$min_baris != 2 || cek_baris_choice$max_baris != 2) {
  stop("Masih ada choice_id yang tidak memiliki 2 baris kandidat.")
}

if (!all(cek_pilihan$jumlah_terpilih == 1)) {
  stop("Masih ada choice set yang jumlah kandidat terpilihnya bukan 1.")
}

# =========================================================
# 7. MENGATUR REFERENSI LEVEL ATRIBUT
# =========================================================

safe_relevel <- function(x, ref) {
  x <- factor(x)
  if (!ref %in% levels(x)) {
    stop(paste("Level referensi tidak ditemukan:", ref,
               "| Level tersedia:", paste(levels(x), collapse = ", ")))
  }
  relevel(x, ref = ref)
}

data_long <- data_long %>%
  mutate(
    Gender = safe_relevel(Gender, "Perempuan"),
    Usia_Tampak = safe_relevel(Usia_Tampak, "45_55"),
    Tone_Kulit = safe_relevel(Tone_Kulit, "Sawo_Matang"),
    Fitur_Wajah = safe_relevel(Fitur_Wajah, "Tegas_Berwibawa"),
    Gaya_Berpakaian = safe_relevel(Gaya_Berpakaian, "Formal_Rapi"),
    Pendidikan = safe_relevel(Pendidikan, "S1_Ke_Bawah"),
    Ketokohan = safe_relevel(Ketokohan, "Belum_Tokoh_Publik"),
    Pengalaman_Militer = safe_relevel(Pengalaman_Militer, "Tidak_Ada_Militer")
  )

write.csv2(data_long, file.path(folder_data, "data_long_siap_analisis.csv"), row.names = FALSE)
saveRDS(data_long, file.path(folder_model, "data_long_siap_analisis.rds"))

# =========================================================
# 8. ANALISIS AMCE
# =========================================================

model_amce <- feols(
  Chosen ~ Gender + Usia_Tampak + Tone_Kulit + Fitur_Wajah +
    Gaya_Berpakaian + Pendidikan + Ketokohan + Pengalaman_Militer |
    choice_id,
  data = data_long,
  cluster = ~Responden_ID
)

print(summary(model_amce))

sink(file.path(folder_output, "summary_model_amce.txt"))
print(summary(model_amce))
sink()

saveRDS(model_amce, file.path(folder_model, "model_amce.rds"))

# =========================================================
# 9. TABEL HASIL AMCE
# =========================================================

ct_model <- as.data.frame(summary(model_amce)$coeftable)
ct_model$term <- rownames(ct_model)
rownames(ct_model) <- NULL

if ("Estimate" %in% names(ct_model)) names(ct_model)[names(ct_model) == "Estimate"] <- "estimate"
if ("Std. Error" %in% names(ct_model)) names(ct_model)[names(ct_model) == "Std. Error"] <- "std_error"
if ("t value" %in% names(ct_model)) names(ct_model)[names(ct_model) == "t value"] <- "statistic"

p_col <- grep("^Pr\\(", names(ct_model), value = TRUE)
if (length(p_col) == 1) names(ct_model)[names(ct_model) == p_col] <- "p_value"

ci_model <- confint(model_amce)
ci_df <- as.data.frame(ci_model)
names(ci_df)[1:2] <- c("conf_low", "conf_high")
ci_df$term <- rownames(ci_df)
rownames(ci_df) <- NULL

term_map <- tibble(
  term = c(
    "GenderLaki_laki",
    "Usia_Tampak35_45",
    "Tone_KulitCerah",
    "Fitur_WajahRamah_Lembut",
    "Gaya_BerpakaianReligius_Tradisional",
    "PendidikanS2_S3",
    "KetokohanTokoh_Masyarakat_Lokal",
    "Pengalaman_MiliterAda_Militer"
  ),
  atribut = c(
    "Gender",
    "Usia Tampak",
    "Tone Kulit",
    "Fitur Wajah",
    "Gaya Berpakaian",
    "Pendidikan",
    "Ketokohan",
    "Pengalaman Militer"
  ),
  level = c(
    "Laki-laki",
    "35-45 tahun",
    "Cerah",
    "Ramah-lembut",
    "Religius-tradisional",
    "S2/S3",
    "Tokoh masyarakat lokal",
    "Ada pengalaman militer"
  ),
  reference = c(
    "Perempuan",
    "45-55 tahun",
    "Sawo matang",
    "Tegas-berwibawa",
    "Formal rapi",
    "S1 ke bawah",
    "Belum tokoh publik",
    "Tidak ada pengalaman militer"
  )
)

hasil_amce <- ct_model %>%
  left_join(ci_df, by = "term") %>%
  left_join(term_map, by = "term") %>%
  mutate(
    estimate_persen = estimate * 100,
    conf_low_persen = conf_low * 100,
    conf_high_persen = conf_high * 100,
    signif = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      p_value < 0.1 ~ ".",
      TRUE ~ ""
    ),
    status = case_when(
      conf_low > 0 & conf_high > 0 ~ "Signifikan positif",
      conf_low < 0 & conf_high < 0 ~ "Signifikan negatif",
      TRUE ~ "Tidak signifikan"
    )
  ) %>%
  select(
    atribut, level, reference, term,
    estimate, std_error, statistic, p_value,
    conf_low, conf_high,
    estimate_persen, conf_low_persen, conf_high_persen,
    signif, status
  )

print(hasil_amce)

write.csv2(hasil_amce, file.path(folder_output, "hasil_amce_non_reference.csv"), row.names = FALSE)
writexl::write_xlsx(hasil_amce, file.path(folder_output, "hasil_amce_non_reference.xlsx"))
saveRDS(hasil_amce, file.path(folder_model, "hasil_amce_non_reference.rds"))

# =========================================================
# 10. RANKING ATRIBUT
# =========================================================

ranking_atribut <- hasil_amce %>%
  mutate(abs_estimate = abs(estimate)) %>%
  arrange(desc(abs_estimate)) %>%
  mutate(ranking = row_number()) %>%
  select(
    ranking, atribut, level, reference,
    estimate, estimate_persen, p_value, signif,
    conf_low_persen, conf_high_persen, status
  )

write.csv2(ranking_atribut, file.path(folder_output, "ranking_atribut_amce.csv"), row.names = FALSE)
writexl::write_xlsx(ranking_atribut, file.path(folder_output, "ranking_atribut_amce.xlsx"))

# =========================================================
# 11. GRAFIK AMCE NON-REFERENCE
# =========================================================

grafik_amce <- ggplot(
  hasil_amce,
  aes(x = estimate, y = reorder(level, estimate))
) +
  geom_vline(xintercept = 0, linewidth = 0.7) +
  geom_segment(
    aes(x = conf_low, xend = conf_high, y = level, yend = level),
    linewidth = 0.7
  ) +
  geom_point(size = 3) +
  facet_grid(
    atribut ~ .,
    scales = "free_y",
    space = "free_y"
  ) +
  labs(
    title = "Average Marginal Component Effects (AMCE)",
    subtitle = "Pengaruh atribut kandidat terhadap probabilitas dipilih",
    x = "Effect on probability of being chosen",
    y = NULL
  ) +
  theme_minimal() +
  theme(
    strip.text.y = element_text(angle = 0, face = "bold"),
    panel.grid.minor = element_blank(),
    axis.text.y = element_text(size = 9),
    plot.title = element_text(face = "bold")
  )

print(grafik_amce)

ggsave(
  filename = file.path(folder_grafik, "grafik_amce_non_reference.png"),
  plot = grafik_amce,
  width = 8,
  height = 6,
  dpi = 300
)

saveRDS(grafik_amce, file.path(folder_model, "grafik_amce_non_reference.rds"))

# =========================================================
# 12. SIMPAN SEMUA HASIL
# =========================================================

semua_hasil_cbc <- list(
  profiles = profiles,
  design = design,
  inspect_basic = inspect_basic,
  data_long = data_long,
  cek_jumlah_responden = cek_jumlah_responden,
  cek_baris_responden = cek_baris_responden,
  cek_baris_choice = cek_baris_choice,
  cek_pilihan = cek_pilihan,
  cek_dapil = cek_dapil,
  model_amce = model_amce,
  hasil_amce = hasil_amce,
  ranking_atribut = ranking_atribut,
  grafik_amce = grafik_amce
)

saveRDS(semua_hasil_cbc, file.path(folder_model, "semua_hasil_cbc.rds"))

cat("\nAnalisis selesai. Semua file disimpan di folder:\n")
cat(folder_simpan, "\n")
