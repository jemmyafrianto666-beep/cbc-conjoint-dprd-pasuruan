# cbc-conjoint-dprd-pasuruan
Data, design, and R scripts for choice-based conjoint analysis of voter preferences toward DPRD candidates in Pasuruan.
# CBC Conjoint DPRD Pasuruan

This repository contains supporting files for a choice-based conjoint (CBC) analysis of voter preferences toward DPRD candidates in Pasuruan, Indonesia.

## Repository Contents

* `Data_Responden_100.xlsx`
  Anonymized respondent dataset used in the study.

* `cbc_profiles_final.csv`
  Complete attribute profiles generated for the CBC design.

* `cbc_design_final_excel.csv`
  Final choice-based conjoint design used in the survey.

## Research Design

The study uses a choice-based conjoint design to examine how candidate attributes influence voter preferences. Respondents were presented with paired hypothetical DPRD candidate profiles and asked to choose the candidate they would be more likely to support.

The candidate profiles include visual and background attributes, such as gender, apparent age, skin tone, facial impression, clothing style, education, local prominence, and military experience.

## Software and Package

The CBC profiles and design were generated using RStudio with the `cbcTools` package.

## Citation for cbcTools

Helveston, J. P. (2025). *cbcTools: Design and Analyze Choice-Based Conjoint Experiments*. R package. https://jhelvy.github.io/cbcTools/

## Data Ethics

The respondent data provided in this repository has been anonymized. Personal identifiers such as names, contact information, and detailed addresses are not included.

## Notes

This repository is intended to support research transparency and documentation. The full interpretation of the analysis is provided in the thesis manuscript.
