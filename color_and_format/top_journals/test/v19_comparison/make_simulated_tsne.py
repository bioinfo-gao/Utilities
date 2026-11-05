from pathlib import Path
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
p=Path(__file__).resolve().parent
with (p.parent/'04_selected_three_tones_light_medium_dark_v19.csv').open() as f:rows=list(csv.DictReader(f))
rng=np.random.default_rng(1905)
centers=np.array([[-7,5],[0,7],[7,5],[-8,-1],[-1,0],[7,-1],[-6,-7],[1,-7],[8,-7]])
points=[];groups=[]
for i,center in enumerate(centers):
 n=650
 theta=rng.uniform(0,2*np.pi);rot=np.array([[np.cos(theta),-np.sin(theta)],[np.sin(theta),np.cos(theta)]])
 z=rng.normal(size=(n,2))*[1.35,.72]
 z[:,1]+=.18*(z[:,0]**2-1)
 points.append(z@rot.T+center);groups.extend([i]*n)
xy=np.vstack(points);groups=np.array(groups)
order=rng.permutation(len(groups))
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'pdf.fonttype':42})
fig,axs=plt.subplots(1,3,figsize=(16,6),sharex=True,sharey=True)
for ax,tone in zip(axs,['light','medium','dark']):
 colors=[r[f'{tone}_hex'] for r in rows]
 sc=ax.scatter(xy[order,0],xy[order,1],c=np.array(colors)[groups[order]],s=4,alpha=1,linewidths=0,rasterized=True)
 assert len(sc.get_offsets())==5850
 for i,c in enumerate(centers):
  ax.text(c[0],c[1]+2,str(i),fontsize=11,ha='center',color='#222222',fontweight='bold')
 ax.set_title(tone.title()+' tones',fontsize=14);ax.set_aspect('equal');ax.set_xlim(-12,12);ax.set_ylim(-11,11)
 ax.set_xticks([]);ax.set_yticks([]);ax.set_xlabel('t-SNE 1')
 for spine in ax.spines.values():spine.set_visible(False)
 ax.annotate('',xy=(-7.5,-10),xytext=(-11,-10),arrowprops={'arrowstyle':'->','lw':1,'color':'#333333'})
 ax.annotate('',xy=(-11,-6.5),xytext=(-11,-10),arrowprops={'arrowstyle':'->','lw':1,'color':'#333333'})
axs[0].set_ylabel('t-SNE 2')
handles=[Line2D([],[],marker='o',ls='',markerfacecolor=r['medium_hex'],markeredgewidth=0,markersize=7,label=f'{i}  {r["family"]}') for i,r in enumerate(rows)]
fig.legend(handles=handles,loc='lower center',bbox_to_anchor=(.5,.075),ncol=9,frameon=False,fontsize=9)
fig.suptitle('V19 | Simulated single-cell t-SNE-style palette preview',fontsize=17,y=.98)
fig.text(.5,.015,'Synthetic layout, not a computed t-SNE embedding or biological result. 9 clusters × 650 points = 5,850 points per panel.\nIdentical coordinates and point order across tones; legend shows medium-tone family identities.',ha='center',fontsize=10)
fig.tight_layout(rect=[0,.18,1,.93])
for ext in ['png','pdf']:
 f=p/f'03_v19_simulated_single_cell_tsne.{ext}';assert not f.exists()
 fig.savefig(f,dpi=250,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
plt.close(fig)
np.savez_compressed(p/'03_v19_simulated_single_cell_tsne_points.npz',coordinates=xy,cluster=groups,draw_order=order)
print('Saved PNG/PDF and simulated coordinates. Verified 5,850 points per panel, 650 per cluster.')
