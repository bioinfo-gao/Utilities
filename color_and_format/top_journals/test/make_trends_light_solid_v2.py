from pathlib import Path
import colorsys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import to_rgb, to_hex
from matplotlib.patches import Patch, Rectangle
OUT=Path(__file__).resolve().parent
PALETTES={
'01_Nature_reference':['#0072B2','#E69F00','#009E73','#CC79A7','#56B4E9','#D55E00','#F0E442','#000000'],
'03_Cell_reference':['#E76F51','#2A9D8F','#56B4E9','#8FD694','#987EBD','#E9C46A','#3D405B']}
NAMES=[['Blue','Orange','Bluish green','Purple pink','Sky blue','Vermilion','Yellow','Neutral'],['Coral','Teal','Sky blue','Mint','Purple','Gold','Blue grey']]
# Derived candidates: preserve hue; constrain HLS lightness for visible white-background fills.
def pair(c):
 h,l,s=colorsys.rgb_to_hls(*to_rgb(c))
 return (to_hex(colorsys.hls_to_rgb(h,max(.30,min(.46,l*.82)),s)),to_hex(colorsys.hls_to_rgb(h,.72,s*.78)))
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'axes.linewidth':.8,'pdf.fonttype':42,'svg.fonttype':'none','savefig.facecolor':'white'})
rng=np.random.default_rng(31)
data=rng.normal(size=(4,2,18))*.7+np.array([[4,5.4],[5,6.1],[4.5,5.6],[5.4,6.8]])[:,:,None]
time=np.arange(5)
means=data.mean(2);sem=data.std(2,ddof=1)/np.sqrt(18)
rows=[]
def save(fig,name):
 fig.savefig(OUT/(name+'.png'),dpi=200,bbox_inches='tight')
 fig.savefig(OUT/(name+'.pdf'),bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None})
 plt.close(fig)
for pidx,(scheme,base) in enumerate(PALETTES.items()):
 if scheme != '03_Cell_reference': continue
 pairs=[pair(c) for c in base]
 for name,c,(dark,light) in zip(NAMES[pidx],base,pairs): rows.append((scheme,name,c,dark,light))
 # Four distinct hues in each example; full palette retained on swatch.
 ids=[0,1,2,3] if pidx==0 else [0,1,2,4]
 colors=[pairs[i] for i in ids]
 for kind in ['trends']:
  fig,axs=plt.subplots(1,4,figsize=(12,3.5),sharey=True)
  for j,ax in enumerate(axs):
   dark,light=colors[j]
   if kind=='bars':
    ax.bar([0,1],means[j],yerr=sem[j],color=[light,dark],width=.65,edgecolor='#444444',linewidth=.6,capsize=3)
    ax.set_xticks([0,1],['Control','Treatment']);ax.set_ylim(0,8.5)
   elif kind=='boxes':
    bp=ax.boxplot(data[j].T,positions=[0,1],widths=.55,patch_artist=True,medianprops={'color':'black','linewidth':1.4},showfliers=False)
    for box,c in zip(bp['boxes'],[light,dark]):box.set_facecolor(c);box.set_edgecolor('#444444')
    for k,c in enumerate([light,dark]):
     jitter=np.linspace(-.15,.15,18)
     ax.scatter(k+jitter,data[j,k],s=16,c=c,edgecolors='#444444',linewidths=.4,zorder=3)
    ax.set_xticks([0,1],['Control','Treatment']);ax.set_ylim(0,9)
   else:
    for k,(c,style,marker) in enumerate([(light,'-','o'),(dark,'--','s')]):
     y=2+j*.3+time*(.4+.12*k)+k*.7+np.sin(time)*.2
     ax.errorbar(time,y,yerr=.18+.03*time,color=c,linestyle=style,marker=marker,markersize=5,capsize=2,label=['Control','Treatment'][k])
    ax.set_xticks(time);ax.set_xlabel('Time (days)');ax.set_ylim(0,6.5)
   ax.set_title(f'Category {chr(65+j)}',fontsize=11)
   ax.tick_params(direction='out')
  axs[0].set_ylabel('Simulated response (a.u.)')
  fig.suptitle(f'{scheme.replace("_"," ")} | {kind.title()} | light = Control; dark = Treatment',y=1.07,fontsize=12)
  fig.text(.5,-.03,'Synthetic data only. Hue = category; tone = condition. Same data in both palette families.',ha='center',fontsize=9,color='#444444')
  fig.tight_layout()
  save(fig,f'{scheme}_{kind}_light_solid_dark_dashed_v2')
print('Created new v2 PNG and PDF; originals preserved')
