from pathlib import Path
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=Path(__file__).resolve().parent
pal={}
for v in [13,14]:
 with (p.parent/f'04_selected_three_tones_light_medium_dark_v{v}.csv').open() as f:pal[v]=list(csv.DictReader(f))
rng=np.random.default_rng(101);data=rng.normal(size=(3,24))*.65+np.array([4,5.1,6.2])[:,None]
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'pdf.fonttype':42,'axes.spines.top':False,'axes.spines.right':False})
def box(ax,r):
 bp=ax.boxplot(data.T,positions=[0,1,2],widths=.6,patch_artist=True,showfliers=False,medianprops={'color':'white' if r['family']=='Neutral' else 'black','linewidth':2.3})
 for patch,key in zip(bp['boxes'],['light_hex','medium_hex','dark_hex']):patch.set_facecolor(r[key]);patch.set_edgecolor('#333333')
 ax.set_xticks([0,1,2],['Light','Medium','Dark']);ax.set_ylim(2,8.2)
def save(fig,stem):
 for ext in ['png','pdf']:
  f=p/f'{stem}.{ext}';assert not f.exists();fig.savefig(f,dpi=200,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
 plt.close(fig)
fig,axs=plt.subplots(3,3,figsize=(14,11),sharey=True)
for ax,r in zip(axs.flat,pal[14]):box(ax,r);ax.set_title(r['family'],fontweight='bold')
for ax in axs[:,0]:ax.set_ylabel('Simulated response')
fig.suptitle('V14 candidate | Nine families | Box plots',fontsize=18)
fig.text(.5,.01,'Identical synthetic data (24 per box). Neutral medians white; all other medians black.',ha='center',fontsize=11)
fig.tight_layout(rect=[0,.035,1,.95],h_pad=2);save(fig,'01_v14_nine_families_boxplots')
fig,axs=plt.subplots(2,3,figsize=(14,8),sharey=True)
for i,v in enumerate([13,14]):
 for ax,fam in zip(axs[i],['Teal','Sky blue','Mint']):
  box(ax,next(r for r in pal[v] if r['family']==fam));ax.set_title(f'V{v} | {fam}',fontweight='bold')
 axs[i,0].set_ylabel('Simulated response')
fig.suptitle('Box-plot comparison | V13 (top) vs V14 candidate (bottom)',fontsize=17)
fig.text(.5,.01,'Same data, axes and median lines. Only the Mint fills differ between versions.',ha='center',fontsize=11)
fig.tight_layout(rect=[0,.04,1,.94],h_pad=2);save(fig,'02_v13_vs_v14_boxplots')
print('Created 2 box-plot figures, PNG/PDF. Existing files preserved.')
