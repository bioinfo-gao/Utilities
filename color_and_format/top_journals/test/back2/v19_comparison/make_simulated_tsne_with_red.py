from pathlib import Path
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
p=Path(__file__).resolve().parent
with (p.parent/'04_selected_three_tones_light_medium_dark_v19.csv').open() as f:rows=list(csv.DictReader(f))
rows.append(dict(family='Pure red',light_hex='#EF9292',medium_hex='#DF3030',dark_hex='#A91D1D'))
rng=np.random.default_rng(1905)
centers=np.array([[-7,6],[0,7],[7,6],[-8,0],[-1,1],[7,0],[-7,-7],[0,-7],[7,-7],[0,-2.8]])
points=[];groups=[]
for i,center in enumerate(centers):
 theta=rng.uniform(0,2*np.pi);rot=np.array([[np.cos(theta),-np.sin(theta)],[np.sin(theta),np.cos(theta)]])
 z=rng.normal(size=(650,2))*[1.15,.65];z[:,1]+=.14*(z[:,0]**2-1)
 points.append(z@rot.T+center);groups.extend([i]*650)
xy=np.vstack(points);groups=np.array(groups);order=rng.permutation(len(groups))
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'pdf.fonttype':42})
fig,axs=plt.subplots(1,3,figsize=(17,6),sharex=True,sharey=True)
for ax,tone in zip(axs,['light','medium','dark']):
 colors=[r[f'{tone}_hex'] for r in rows]
 sc=ax.scatter(xy[order,0],xy[order,1],c=np.array(colors)[groups[order]],s=4,linewidths=0,rasterized=True)
 assert len(sc.get_offsets())==6500
 for i,c in enumerate(centers):ax.text(c[0],c[1]+1.8,str(i),fontsize=11,ha='center',fontweight='bold',color='#222222')
 ax.set_title(tone.title()+' tones',fontsize=14);ax.set_aspect('equal');ax.set_xlim(xy[:,0].min()-1,xy[:,0].max()+1);ax.set_ylim(xy[:,1].min()-1,xy[:,1].max()+1)
 assert ((xy[:,0]>ax.get_xlim()[0])&(xy[:,0]<ax.get_xlim()[1])&(xy[:,1]>ax.get_ylim()[0])&(xy[:,1]<ax.get_ylim()[1])).all()
 ax.set_xticks([]);ax.set_yticks([]);ax.set_xlabel('t-SNE 1')
 for spine in ax.spines.values():spine.set_visible(False)
axs[0].set_ylabel('t-SNE 2')
handles=[Line2D([],[],marker='o',ls='',markerfacecolor=r['medium_hex'],markeredgewidth=0,markersize=7,label=f'{i}  {r["family"]}') for i,r in enumerate(rows)]
fig.legend(handles=handles,loc='lower center',bbox_to_anchor=(.5,.075),ncol=5,frameon=False,fontsize=10)
fig.suptitle('V19 + Pure red candidate | Simulated single-cell t-SNE-style preview',fontsize=17,y=.98)
fig.text(.5,.012,'Synthetic layout, not a computed t-SNE embedding. 10 clusters × 650 points = 6,500 points per panel.\nIdentical coordinates across tones. Compare Pure red (9), Coral (0), and Purple pink (6); legend uses medium tones.',ha='center',fontsize=10)
fig.tight_layout(rect=[0,.22,1,.93])
for ext in ['png','pdf']:
 f=p/f'04_v19_plus_pure_red_simulated_tsne.{ext}';assert not f.exists()
 fig.savefig(f,dpi=250,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
plt.close(fig)
with (p/'04_v19_plus_pure_red_palette.csv').open('x') as f:
 w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
np.savez_compressed(p/'04_v19_plus_pure_red_points.npz',coordinates=xy,cluster=groups,draw_order=order)
print('Verified 6,500 points per panel; all points inside bounds. Saved PNG/PDF and candidate colours.')
