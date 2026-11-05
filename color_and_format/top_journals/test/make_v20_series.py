from pathlib import Path
import csv,colorsys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.colors import to_rgb
p=Path(__file__).resolve().parent;q=p/'v20_comparison';q.mkdir(exist_ok=False)
with (p/'04_selected_three_tones_light_medium_dark_v19.csv').open() as f:rows=list(csv.DictReader(f))
for r in rows:
 if r['family']=='Purple':r['dark_hex']='#70558F'
 if r['family']=='Purple pink':r['dark_hex']='#A34B7C'
rows.append(dict(family='Pure red',light_hex='#E87878',medium_hex='#E64B4B',dark_hex='#BC3535'))
canonical=p/'04_selected_three_tones_light_medium_dark_v20.csv'
with canonical.open('x') as f:
 w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
for r in rows:
 ls=[colorsys.rgb_to_hls(*to_rgb(r[k]))[1] for k in ['light_hex','medium_hex','dark_hex']]
 assert ls[0]>ls[1]>ls[2],r
plt.rcParams.update({'font.family':'DejaVu Sans','pdf.fonttype':42})
def save(fig,base):
 for ext in ['png','pdf']:
  target=Path(str(base)+'.'+ext);assert not target.exists()
  fig.savefig(target,dpi=220,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
 plt.close(fig)
fig,ax=plt.subplots(figsize=(10,10.2));ax.set_xlim(-2.1,6);ax.set_ylim(-.6,10.6);ax.axis('off')
for x,t in zip([0,2,4],['Light','Medium','Dark']):ax.text(x+.85,10.15,t,ha='center',fontsize=15,fontweight='bold')
for i,r in enumerate(rows):
 y=9-i;ax.text(-.15,y+.43,r['family'],ha='right',va='center',fontsize=12)
 for x,k in zip([0,2,4],['light_hex','medium_hex','dark_hex']):
  c=r[k];ax.add_patch(Rectangle((x,y+.2),1.7,.55,facecolor=c,edgecolor='#888888',linewidth=.6));ax.text(x+.85,y-.02,c.upper(),ha='center',fontsize=11)
fig.suptitle('Selected palette | Three tones | v20 candidate',fontsize=19,y=.96)
fig.text(.5,.04,'Purple and Purple pink dark tones softened; Pure red added.\nOther tones retained from V19. Ten families, thirty swatches.',ha='center',fontsize=10)
save(fig,p/'04_selected_three_tones_light_medium_dark_v20')
rng=np.random.default_rng(101);data=rng.normal(size=(3,24))*.65+np.array([4,5.1,6.2])[:,None]
fig,axs=plt.subplots(2,5,figsize=(19,8),sharey=True)
for ax,r in zip(axs.flat,rows):
 bp=ax.boxplot(data.T,positions=[0,1,2],widths=.6,patch_artist=True,showfliers=False,medianprops={'color':'white' if r['family']=='Neutral' else 'black','linewidth':2.3})
 for patch,k in zip(bp['boxes'],['light_hex','medium_hex','dark_hex']):patch.set_facecolor(r[k]);patch.set_edgecolor('#333333')
 ax.set_xticks([0,1,2],['Light','Medium','Dark']);ax.set_ylim(2,8.2);ax.set_title(r['family'],fontweight='bold');ax.spines[['top','right']].set_visible(False)
for ax in axs[:,0]:ax.set_ylabel('Simulated response')
fig.suptitle('V20 candidate | Ten families | Box plots',fontsize=18)
fig.text(.5,.01,'Identical synthetic data: 24 per box. Neutral medians white; all other medians black.',ha='center',fontsize=11)
fig.tight_layout(rect=[0,.04,1,.94],h_pad=2)
save(fig,q/'01_v20_ten_families_boxplots')
# Reuse exact previous synthetic layout and rendering, reading only the new canonical palette.
s=(p/'v19_comparison/make_simulated_tsne_with_red_v2.py').read_text()
s=s.replace("p.parent/'04_selected_three_tones_light_medium_dark_v19.csv'","p.parent/'04_selected_three_tones_light_medium_dark_v20.csv'")
s=s.replace("rows.append(dict(family='Pure red',light_hex='#E87878',medium_hex='#E64B4B',dark_hex='#BC3535'))",'')
s=s.replace('V19 + Pure red v2 candidate','V20 candidate').replace('05_v19_plus_pure_red_v2','02_v20')
(q/'make_simulated_tsne.py').write_text(s)
print('V20 colour card and box plots created; all 10 light-medium-dark sequences verified.')
