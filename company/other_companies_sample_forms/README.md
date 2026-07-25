# Other Companies' Sample Submission Forms — Reference Only

Fetched 2026-07-22 for comparison against our own `Sample_Registration_Form.xlsx`
(see the parent folder). These are **real forms submitted by a real client lab**
(University of Washington, Roberts Lab, project "E5 coral time series"), archived
in that lab's own public GitHub data repository — not blank templates scraped
from a vendor site, so the filled-in values are real project data, but the
**column/field structure is what matters here**, not the sample values.

Source repo: https://github.com/urol-e5/timeseries_molecular
(`M-multi-species/data/`), commit `841df3e39...`.

| File | Company | Assay | Notes |
| :--- | :---: | :---: | :--- |
| `Azenta_RNA_Sequencing_submission_form.xlsx` | Azenta Life Sciences (formerly GENEWIZ) | Bulk RNA-seq | Has a **Biosafety Level (BSL)** column per sample — see comparison below |
| `Azenta_WGBS_submission_form.xls` | Azenta Life Sciences (formerly GENEWIZ) | Whole-Genome Bisulfite Sequencing | Legacy `.xls`; internal file metadata shows author "Kelly Moore, GW/US" (GW = GENEWIZ) and last-saved 2024-12-31, i.e. a genuine internally-issued Azenta document, not a mockup |

Azenta is a commercial NGS service provider — same business model as us — so its
column structure (required fields marked with `*` directly in the header, a
per-sample `Biosafety Level (BSL)` column, split QC-method columns for
Fluorescence/Spectrophotometry/Electrophoresis) is the most directly comparable
reference we found. The Norwegian Sequencing Centre (an academic core facility,
more compliance-heavy) was also reviewed for its field list — see the
2026-07-22 conversation — but it had no downloadable original form file, only a
LIMS parser script the field names were reverse-engineered from, so it isn't
saved here as a document.

**Gap identified vs. our form**: neither of our forms (`Sample_Registration_Form.xlsx`
/ `_N1.xlsx`) has a biosafety/hazardous-sample declaration field, which both
Azenta and NSC require. Not yet incorporated — pending decision.
