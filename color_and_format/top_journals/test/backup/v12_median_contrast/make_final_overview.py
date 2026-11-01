from pathlib import Path
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=Path(__file__).resolve().parent
with (p.parent/'04_selected_three_tones_light_medium_dark_v12.csv').open() as f: rows=list(csv.DictReader(f))
rng=np.random.default_rng(101)
data=rng.normal(size=(3,24))*.65+np.array([4,5.1,6.2])[:,None]
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'pdf.fonttype':42,'axes.spines.top':False,'axes.spines.right':False})
fig,axs=plt.subplots(3,3,figsize=(15,12),sharey=True)
for ax,r in zip(axs.flat,rows):
 cs=[r[k] for k in ['light_hex','medium_hex','dark_hex']]
 mc='white' if r['family']=='Neutral' else 'black'
 bp=ax.boxplot(data.T,positions=[0,1,2],widths=.6,patch_artist=True,showfliers=False,medianprops={'color':mc,'linewidth':2.3,'zorder':5})
 for box,c in zip(bp['boxes'],cs):box.set_facecolor(c);box.set_edgecolor('#333333')
 assert all(line.get_color()==mc for line in bp['medians'])
 ax.set_xticks([0,1,2],['Light','Medium','Dark']);ax.set_ylim(2,8.2)
 ax.set_title(r['family'],fontsize=14,fontweight='bold',pad=12)
for ax in axs[:,0]:ax.set_ylabel('Simulated response')
fig.suptitle('V12 | Nine colour families\nMedian lines: white for Neutral; black for all other families',fontsize=18,y=.99)
fig.text(.5,.015,'Synthetic data: 24 observations per box; identical data across panels. Whiskers and borders remain black / dark grey.',ha='center',fontsize=11)
fig.tight_layout(rect=[0,.04,1,.94],h_pad=2,w_pad=2)
for ext in ['png','pdf']:
 f=p/f'v12_median_final_rule_overview.{ext}';assert not f.exists()
 fig.savefig(f,dpi=220,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
plt.close(fig)
print('9 panels, 27 boxes; all median colours checked against the new rule.')
