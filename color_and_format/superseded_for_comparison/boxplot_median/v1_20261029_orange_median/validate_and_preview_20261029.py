"""Synthetic style comparison only; no biological claims. Run from any directory."""
from pathlib import Path
import sys, subprocess, csv, json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'python/color_figures_with_preconfigured_sets'))
import palette_priority as p
OUT=Path(__file__).resolve().parent/'preview_20261029'
OUT.mkdir(exist_ok=True)
# Cross-language comparison includes fallback, role variants, and invalid input.
cases=[]
for scheme,rel,ns in [('auto','independent',[1,4,7,8]),('Paired_4','independent',[1,4]),('auto','paired',[2,6,8]),('Default_A','independent',[4]),('Default_B','independent',[4])]:
 for n in ns:
  for role in ['fill','stroke']:cases.append((n,rel,role,scheme))
rfile=OUT/'cross_language_check.R'
rfile.write_text('source("'+str(ROOT/'R/color_figures_with_preconfigured_sets/palette_priority.R')+'")\n'+ '\n'.join('cat(paste(select_palette(%d, "%s", "%s", "%s"), collapse=" "), "\\n", sep="")'%c for c in cases)+'\n')
res=subprocess.run(['conda','run','-n','regular_bioinfo','Rscript',str(rfile)],capture_output=True,text=True)
if res.returncode:raise RuntimeError(res.stdout+res.stderr)
actual=[x.strip() for x in res.stdout.splitlines() if x.startswith('#')]
expected=[' '.join(p.select_palette(*c)) for c in cases]
assert actual==expected,(actual,expected)
for args in [(0,), (True,), (3,'paired'),(10,'paired'),(8,'independent','fill','Categorical_7'),(5,'independent','fill','Paired_4'),(2,'independent','text')]:
 try:p.select_palette(*args)
 except ValueError:pass
 else:raise AssertionError(args)
p.check_default_b_palette_unchanged()
# Verify role-specific contrast over both complete new schemes.
contrasts=[]
for scheme,n,rel in [('Paired_4',8,'paired'),('Categorical_7',7,'independent')]:
 for role in ['fill','stroke']:
  for i,h in enumerate(p.select_palette(n,rel,role,scheme),1):
   c=p.contrast_vs_white(h);assert c >= (1.1 if role=='fill' else 1.5)
   contrasts.append([scheme,role,i,h,round(c,4)])
with (OUT/'contrast_audit.csv').open('w') as f:
 w=csv.writer(f);w.writerow(['scheme','role','position','hex','contrast_white']);w.writerows(contrasts)
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.spines.top':False,'axes.spines.right':False,'axes.linewidth':.65,'pdf.fonttype':42})
rng=np.random.default_rng(20261029)
points=[rng.normal([i*2,i%2], [.4,.35],(12,2)) for i in range(4)]
values=rng.normal([2,3,2.6,4],.35,(20,4))
x=np.arange(5);ys=np.array([(i+1)*.3+x*(.2+i*.1) for i in range(4)])
comp=np.array([[.25,.20,.3,.25],[.20,.3,.2,.3],[.35,.2,.25,.2]])
fig,axs=plt.subplots(4,3,figsize=(12,11),layout='constrained')
for j,scheme in enumerate(['Default_A','Paired_4','Categorical_7']):
 fills=p.select_palette(4,scheme=scheme);strokes=p.select_palette(4,role='stroke',scheme=scheme)
 axs[0,j].set_title(scheme)
 for i,xy in enumerate(points):axs[0,j].scatter(*xy.T,c=fills[i],s=38,edgecolors='#555555',linewidths=.3,label='G'+str(i+1))
 assert sum(len(c.get_offsets()) for c in axs[0,j].collections)==48
 axs[0,j].set_xlabel('Synthetic axis 1');axs[0,j].set_ylabel('Synthetic axis 2 (48 points)')
 bp=axs[1,j].boxplot(values,patch_artist=True,widths=.55)
 for box,c in zip(bp['boxes'],fills):box.set_facecolor(c);box.set_edgecolor('#555555');box.set_linewidth(.65)
 axs[1,j].set_ylabel('Synthetic expression');axs[1,j].set_xticks(range(1,5),['G1','G2','G3','G4'])
 for i,y in enumerate(ys):axs[2,j].plot(x,y,c=strokes[i],marker=['o','s','^','D'][i],ms=4,lw=1.5,label='G'+str(i+1))
 axs[2,j].set_xlabel('Synthetic time');axs[2,j].set_ylabel('Synthetic response')
 bottom=np.zeros(3)
 for i,c in enumerate(fills):axs[3,j].bar(range(3),comp[:,i],bottom=bottom,color=c,width=.6,edgecolor='white',linewidth=.5);bottom+=comp[:,i]
 axs[3,j].set_ylim(0,1);axs[3,j].set_ylabel('Synthetic fraction');axs[3,j].set_xticks(range(3),['S1','S2','S3'])
 axs[0,j].legend(loc='lower center',bbox_to_anchor=(.5,1.13),ncol=4,frameon=False,fontsize=8)
fig.suptitle('Same synthetic data and layout; scheme comparison (not biological results)',fontsize=12)
for ext in ['pdf','png']:fig.savefig(OUT/f'scheme_comparison.{ext}',dpi=180,metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
plt.close(fig)
fig,axs=plt.subplots(3,1,figsize=(11,4),layout='constrained')
for ax,(name,n,rel,role) in zip(axs,[('Paired_4',8,'paired','fill'),('Categorical_7',7,'independent','fill'),('Categorical_7',7,'independent','stroke')]):
 cols=p.select_palette(n,rel,role,name)
 for i,h in enumerate(cols):ax.barh(0,1,left=i,color=h,height=.65);ax.text(i+.5,-.48,h,ha='center',fontsize=9)
 ax.set_xlim(0,n);ax.set_ylim(-.7,.6);ax.set_title(name+' / '+role,loc='left',fontsize=10);ax.axis('off')
for ext in ['pdf','png']:fig.savefig(OUT/f'new_scheme_swatches.{ext}',dpi=180,metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
plt.close(fig)
report={'cross_language_cases_passed':len(cases),'python_invalid_cases_rejected':7,'legacy_B_guard':'passed','contrast_checks':len(contrasts),'synthetic_points_per_panel':48,'colour_vision_simulation':'not performed'}
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
