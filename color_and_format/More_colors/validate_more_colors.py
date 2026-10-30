"""Validate explicit supplementary palettes; create a new audit directory each run."""
from pathlib import Path
from datetime import datetime
import csv
import importlib.util
import json
import re
import subprocess
import sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

ROOT = Path(__file__).resolve().parent
UTIL = ROOT.parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(UTIL / 'python/color_figures_with_preconfigured_sets'))
import palette_priority as p

OUT = ROOT / ('validation_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
OUT.mkdir(exist_ok=False)
rows = list(csv.DictReader((ROOT / 'palettes.csv').open()))
groups = {}
for row in rows:
    assert re.fullmatch(r'#[0-9A-F]{6}', row['fill']), row
    groups.setdefault(row['scheme'], []).append(row)
for name, rs in groups.items():
    assert [int(r['position']) for r in rs] == list(range(1, len(rs)+1))
    assert len({r['kind'] for r in rs}) == 1
    assert len({r['fill'] for r in rs}) == len(rs)

# Compare the unchanged API's output against the original source snapshot.
archive = UTIL.parent / 'AI_and_Agent/Agent_Assets/superseded_for_comparison/palette_more_colors/v1_20261029_before_more_colors'
spec = importlib.util.spec_from_file_location('palette_before_more', archive / 'color_and_format/python/color_figures_with_preconfigured_sets/palette_priority.py')
old = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = old
spec.loader.exec_module(old)
# Snapshot location differs; original API resolves its CSV relative to __file__.
old.__file__ = p.__file__
legacy = [(n, rel, role, scheme)
          for scheme, rel, ns in [('auto','independent',[1,4,7,8,12]),
                                  ('auto','paired',[2,8]),
                                  ('Paired_4','independent',[1,4]),
                                  ('Default_A','independent',[4]),
                                  ('Default_B','independent',[4])]
          for n in ns for role in ['fill','stroke']]
for args in legacy:
    assert p.select_palette(*args) == old.select_palette(*args), args

expected, commands = [], []
for args in legacy:
    expected.append(' '.join(p.select_palette(*args)).upper())
    commands.append('cat(paste(select_palette(%s), collapse=" "), "\\n", sep="")' %
                    ','.join(json.dumps(x) for x in args))
for name, rs in groups.items():
    if rs[0]['kind'] == 'qualitative':
        for n in [1, len(rs)]:
            for role in ['fill', 'stroke']:
                got = p.select_palette(n, role=role, scheme=name)
                expected.append(' '.join(got).upper())
                commands.append(f'cat(paste(select_palette({n}, role="{role}", scheme="{name}"), collapse=" "), "\\n", sep="")')
    else:
        for reverse in [False, True]:
            got = p.color_scale(name, reverse=reverse)
            assert got == [r['fill'] for r in (list(reversed(rs)) if reverse else rs)]
            expected.append(' '.join(got).upper())
            commands.append(f'cat(paste(color_scale("{name}", reverse={str(reverse).upper()}), collapse=" "), "\\n", sep="")')

bad = [(lambda: p.select_palette(10, scheme='Nature_9'), 'select_palette(10, scheme="Nature_9")'),
       (lambda: p.select_palette(2, relationship='paired', scheme='Nature_3'), 'select_palette(2, relationship="paired", scheme="Nature_3")'),
       (lambda: p.select_palette(2, scheme='Nature_Sequential_Blue'), 'select_palette(2, scheme="Nature_Sequential_Blue")'),
       (lambda: p.select_palette(2, scheme='Scientific_Red'), 'select_palette(2, scheme="Scientific_Red")'),
       (lambda: p.color_scale('Nature_9'), 'color_scale("Nature_9")'),
       (lambda: p.color_scale('missing'), 'color_scale("missing")'),
       (lambda: p.color_scale('Scientific_Red', reverse=1), 'color_scale("Scientific_Red", reverse=1)')]
for fn, expr in bad:
    try:
        fn()
    except ValueError:
        pass
    else:
        raise AssertionError(expr)
    commands.append(f'stopifnot(inherits(try({expr}, silent=TRUE), "try-error"))')
rfile = OUT / 'cross_language.R'
rfile.write_text(f'source("{UTIL}/R/color_figures_with_preconfigured_sets/palette_priority.R")\n' + '\n'.join(commands) + '\n')
res = subprocess.run(['conda','run','-n','regular_bioinfo','Rscript',str(rfile)], capture_output=True, text=True)
assert res.returncode == 0, res.stdout + res.stderr
actual = [line.strip().upper() for line in res.stdout.splitlines() if line.startswith('#')]
assert actual == expected, (actual, expected)

def luminance(h):
    v = np.array([int(h[i:i+2],16)/255 for i in (1,3,5)])
    v = np.where(v <= .04045, v/12.92, ((v+.055)/1.055)**2.4)
    return float(v @ [.2126,.7152,.0722])

audit = []
for name, rs in groups.items():
    if rs[0]['kind'] == 'sequential':
        ls = [luminance(r['fill']) for r in rs]
        assert all(a > b for a,b in zip(ls,ls[1:])), (name, ls)
    for row in rs:
        c = p.contrast_vs_white(row['fill'])
        audit.append([name,row['position'],row['fill'],round(c,4),c>=1.1,c>=1.5])
with (OUT/'contrast_audit.csv').open('w') as f:
    w=csv.writer(f)
    w.writerow(['scheme','position','fill','contrast_white','fill_threshold','stroke_threshold_raw_color'])
    w.writerows(audit)

plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'pdf.fonttype':42})
fig, axes = plt.subplots(len(groups), 1, figsize=(11, len(groups)*.7), layout='constrained')
for ax, (name, rs) in zip(axes, groups.items()):
    cols = [r['fill'] for r in rs]
    if rs[0]['kind'] == 'qualitative':
        ax.imshow(np.arange(len(cols))[None,:], aspect='auto', cmap=matplotlib.colors.ListedColormap(cols), interpolation='nearest')
    else:
        ax.imshow(np.linspace(0,1,256)[None,:], aspect='auto', cmap=LinearSegmentedColormap.from_list(name,cols))
    ax.set_title(name+' | '+rs[0]['kind'],loc='left',fontsize=9)
    ax.set_xticks([]); ax.set_yticks([])
fig.savefig(OUT/'palette_preview.pdf', metadata={'CreationDate':None,'ModDate':None})
fig.savefig(OUT/'palette_preview.png', dpi=160)
plt.close(fig)
result={'schemes':len(groups),'cross_language_cases':len(expected),
        'legacy_cases_unchanged':len(legacy),'invalid_calls_rejected_per_language':len(bad),
        'sequential_luminance':'strictly decreasing low-to-high',
        'color_vision_simulation':'not performed', 'output':str(OUT)}
(OUT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
