# Reference: sample submission forms from other sequencing/analysis providers

Searched 2026-07-20 to inform the redesign of `Sample_Registration_Form_ZG.xlsx`
(rows 15-22 restructure: required Analysis Purpose/Comparisons field, optional
Filtering/QC/Stats field, sole-basis-for-pricing declaration).

## Saved

- **`reference_Marshall_University_Genomics_Core_Analysis_Request_Form.pdf`**
  ([source](https://jcesom.marshall.edu/media/33321/MU-Genomics-Core-Analysis-Request-Form-.pdf))
  — the one directly useful, publicly downloadable form found. A small core-facility
  intake form (comparable scale to us), notable for:
  - "Complete one form for each separate experiment" — matches our "two parts = two forms" rule.
  - Explicit blank fields for comparisons: *"Cell line 1 ___ vs Cell line 2 ___"*,
    *"Define your fold change ratio (R)..."*, *"Number of Biological Replicates ___"* —
    the direct model for our new "Analysis Purpose and Comparisons (REQUIRED)" row
    (state which group is baseline/control, not just prose).
  - Checkbox-style "Data output" list per analysis type (reads only / alignment / variant
    calls / peak calls / statistical analysis) — a good future-reference idea if we ever
    want to itemize deliverables as checkboxes instead of prose (not yet applied).

## Checked but no usable public form found

- **Novogene** — America Sample Submission Guidelines PDF and 3'GEX scRNA-seq fillable
  submission form: both URLs now return 404 (moved/retired since indexed by search).
  Downloads page (novogeneusa.com/resources/downloads/) lists no direct form links;
  actual forms are distributed via account/CSS portal, not public.
- **GENEWIZ / Azenta** — NGS Sample Submission Guidelines page describes the process
  (asterisked required columns, extra columns per project type: sequencing-only/amplicon/
  single-cell/ATAC-seq) but the actual fillable form is behind their online portal
  (`NGS@azenta.com`), not a public download.
- **Psomagen** — order form is generated inside their online ordering portal per order;
  no standalone public template.
- **Eurofins Genomics** — "Sample Submission Guidelines" PDF link returned HTTP 200 but
  the file itself is corrupted/empty at the source (all-null bytes, both via direct
  download and WebFetch) — not usable.
- **UC Riverside, University of Michigan genomics cores** — forms distributed on request
  by email, not public; UMich page blocked (403).

## Takeaway applied to our form

The Marshall form's core lesson — spell out *comparison + which group is baseline*
as explicit blanks rather than leaving it to prose — was applied directly. The
"data output checklist" idea was considered but not applied (client asked for a
narrower required/optional split of the existing field instead); worth revisiting
if the form needs another pass.
