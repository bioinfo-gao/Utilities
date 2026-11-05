from pathlib import Path
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
p=Path(__file__).resolve().parent
with (p.parent/'04_selected_three_tones_light_medium_dark_v21.csv').open() as f:by={r['family']:r for r in csv.DictReader(f)}
with (p.parent.parent/'v21_family_order.csv').open() as f:order=[r['family'] for r in csv.DictReader(f)]
rows=[by[n] for n in order];assert len(rows)==10
rng=np.random.default_rng(2105)
scatter=[rng.normal(size=(16,2))*[.23,.27]+[i,(i%2)*1.2] for i in range(10)]
boxes=[rng.normal(2+i*.25,.3,30) for i in range(10)]
t=np.arange(5);trends=np.array([.3+i*.27+t*(.13+.025*i) for i in range(10)])
fractions=rng.dirichlet(np.ones(10)*3,size=3).T
assert np.allclose(fractions.sum(0),1)
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'pdf.fonttype':42,'axes.spines.top':False,'axes.spines.right':False})
fig,axs=plt.subplots(4,3,figsize=(18,19))
used=set()
for col,tone in enumerate(['light','medium','dark']):
 cs=[r[tone+'_hex'] for r in rows];used.update(c.upper() for c in cs)
 ax=axs[0,col]
 for i,(xy,c) in enumerate(zip(scatter,cs)):
  sc=ax.scatter(xy[:,0],xy[:,1],c=c,s=30,edgecolors='#444444',linewidths=.35)
 assert sum(len(c.get_offsets()) for c in ax.collections)==160
 ax.set_title(tone.title()+' tones',fontsize=16,pad=12);ax.set_xlabel('Synthetic axis 1');ax.set_ylabel('Synthetic axis 2 (160 points)');ax.set_xticks(range(10),range(1,11))
 ax=axs[1,col]
 bp=ax.boxplot(boxes,patch_artist=True,widths=.65,showfliers=True,medianprops={'linewidth':1.7,'zorder':5},flierprops={'marker':'.','markersize':3,'markeredgecolor':'#444444'})
 for r,patch,line,c in zip(rows,bp['boxes'],bp['medians'],cs):
  patch.set_facecolor(c);patch.set_edgecolor('#444444');line.set_color('white' if r['family']=='Neutral' else 'black')
 ax.set_xticks(range(1,11),range(1,11));ax.set_xlabel('Family ID');ax.set_ylabel('Synthetic expression (n = 30 / family)')
 ax=axs[2,col]
 for i,(y,c) in enumerate(zip(trends,cs)):
  ax.plot(t,y,c=c,lw=1.9,marker=['o','s','^','D','v'][i%5],markersize=4,ls=['-','-.','--'][col])
 ax.set_xlabel('Synthetic time');ax.set_ylabel('Synthetic response');ax.set_xticks(t)
 ax=axs[3,col];bottom=np.zeros(3)
 for i,c in enumerate(cs):
  ax.bar(range(3),fractions[i],bottom=bottom,color=c,width=.65,edgecolor='white',linewidth=.6);bottom+=fractions[i]
 ax.set_xticks(range(3),['S1','S2','S3']);ax.set_ylim(0,1);ax.set_ylabel('Synthetic fraction')
for row in range(4):
 lims=[axs[row,c].get_ylim() for c in range(3)];lo=min(l[0] for l in lims);hi=max(l[1] for l in lims)
 for c in range(3):axs[row,c].set_ylim(lo,hi)
fig.suptitle('V21 | All 10 families and 30 tones | Same synthetic data and layout',fontsize=19,y=.995)
handles=[Patch(facecolor=by[n]['medium_hex'],edgecolor='#555555',linewidth=.4,label=f'{i+1}  {n}') for i,n in enumerate(order)]
fig.legend(handles=handles,loc='upper center',bbox_to_anchor=(.5,.975),ncol=5,frameon=False,fontsize=11)
fig.text(.5,.012,'Synthetic examples only. Family order is shared across all panels; legend swatches show medium tones.\nLines: light solid / medium dash-dot / dark dashed. Box medians: Neutral white, all others black.',ha='center',fontsize=11)
fig.tight_layout(rect=[0,.045,1,.925],h_pad=2,w_pad=2)
assert used=={r[k].upper() for r in rows for k in ['light_hex','medium_hex','dark_hex']}
for ext in ['png','pdf']:
 target=p/f'03_v21_all_colours_scheme_comparison.{ext}';assert not target.exists()
 fig.savefig(target,dpi=200,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
plt.close(fig)
with (p/'03_v21_all_colours_scheme_comparison_data.npz').open('xb') as f:np.savez_compressed(f,scatter=np.array(scatter),boxes=np.array(boxes),trends=trends,fractions=fractions)
print('Verified: 12 panels; all 30 tones used; 160 scatter points per panel; fractions sum to 1; colours read from V21; order read from shared SSOT.')
