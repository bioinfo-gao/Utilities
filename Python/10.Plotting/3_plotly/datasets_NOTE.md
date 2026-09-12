# Datasets excluded from merge

The `datasets/` subfolder that belongs next to `2_plotly_more_details.ipynb` (~1.1G, 1185
files) was intentionally **not** copied into this consolidated Utilities tree -- it is bulk
external tutorial data, not personal reference material, and would have bloated this folder
by >1GB.

What it contained: a checkout of the upstream **`plotly/datasets`** repo -- ~200 demo
CSV/parquet/pkl files at the top level plus its `dash-sample-apps/`, `Dash-Course/`,
`Dash-Curriculum/`, `ag-grid/`, `api_docs/`, `Blog/`, `MATLAB/`, `ply/`, `vtk/` subfolders.

## 2026-09-12 -- there is no longer a local copy

The original lived at
`/home/gao/projects_2026H1/Utilities/Python_tested_in_python3.10_and_ipynb/10.Plotting/3_plotly/datasets/`.
That whole H1 archive was retired on 2026-09-12, after a file-by-file **content** check
(md5 of all 1564 files) confirmed everything else in it was already present here or in
`/Work_bio/references/`. This `datasets/` tree was the one bulk item deliberately left
behind -- **do not go looking for a local copy; re-fetch it from upstream instead.**

To re-run these tutorial notebooks:

```bash
cd /home/gao/Utilities/Python/10.Plotting/3_plotly
git clone https://github.com/plotly/datasets.git datasets     # ~1.1G
```

Or pull single files on demand -- the notebook already uses this URL form for at least one
dataset:

```
https://raw.githubusercontent.com/plotly/datasets/master/<name>.csv
```

Do **not** commit the cloned `datasets/` back into this repo (the >10MB pre-commit hook will
block the big files anyway, and the whole point of this note is to keep it out).
