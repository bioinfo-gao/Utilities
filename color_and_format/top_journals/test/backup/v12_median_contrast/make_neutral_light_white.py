from pathlib import Path
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=Path(__file__).resolve().parent
with (p.parent/'04_selected_three_tones_light_medium_dark_v12.csv').open() as f:
 r=next(r for r in csv.DictReader(f) if r['family']=='Neutral')
colors=[r[k] for k in ['light_hex','medium_hex','dark_hex']]
rng=np.random.default_rng(101)
data=rng.normal(size=(3,24))*.65+np.array([4,5.1,6.2])[:,None]
plt.rcParams.update({'font.family':'DejaVu Sans','pdf.fonttype':42,'axes.spines.top':False,'axes.spines.right':False})
fig,axs=plt.subplots(1,2,figsize=(10,4),sharey=True)
for j,ax in enumerate(axs):
 bp=ax.boxplot(data.T,positions=[0,1,2],widths=.6,patch_artist=True,showfliers=False,medianprops={'linewidth':2.2,'zorder':5})
 for k,(box,c) in enumerate(zip(bp['boxes'],colors)):
  box.set_facecolor(c);box.set_edgecolor('#333333')
  bp['medians'][k].set_color('black' if j==0 and k==0 else 'white')
 ax.set_xticks([0,1,2],['Light','Medium','Dark']);ax.set_ylim(2,8.2)
 ax.set_title(['Current: light black; medium/dark white','Preview: all three medians white'][j],fontsize=11)
axs[0].set_ylabel('Simulated response')
fig.suptitle('V12 Neutral | Light-tone median comparison',fontsize=14)
fig.text(.5,.01,'Identical synthetic data and fills. Only the median line in the light box changes.',ha='center',fontsize=10)
fig.tight_layout(rect=[0,.05,1,.93])
for ext in ['png','pdf']:
 target=p/f'v12_neutral_light_white_median_preview.{ext}';assert not target.exists()
 fig.savefig(target,dpi=200,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
print('Saved PNG/PDF; only light-box median differs between panels.')
