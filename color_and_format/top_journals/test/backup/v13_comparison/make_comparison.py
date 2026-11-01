from pathlib import Path
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=Path(__file__).resolve().parent
pal={}
for v in [12,13]:
 with (p.parent/f'04_selected_three_tones_light_medium_dark_v{v}.csv').open() as f:pal[v]=list(csv.DictReader(f))
plt.rcParams.update({'font.family':'DejaVu Sans','pdf.fonttype':42,'axes.spines.top':False,'axes.spines.right':False})
def save(fig,stem):
 for ext in ['png','pdf']:
  f=p/f'{stem}.{ext}';assert not f.exists();fig.savefig(f,dpi=190,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
 plt.close(fig)
t=np.arange(6)
# Nine families, same data and layout, three tones in every panel.
fig,axs=plt.subplots(3,3,figsize=(15,11),sharey=True)
for ax,r in zip(axs.flat,pal[13]):
 for k,(key,ls,m) in enumerate(zip(['light_hex','medium_hex','dark_hex'],['-','-.','--'],['o','^','s'])):
  y=2+k*.65+t*(.43+.08*k)+np.sin(t)*.16
  ax.plot(t,y,color=r[key],ls=ls,marker=m,lw=2.2,label=['Light','Medium','Dark'][k])
 ax.set_title(r['family']);ax.set_xlabel('Time (days)');ax.set_ylim(1.5,7);ax.legend(frameon=False,loc='upper left',fontsize=8)
fig.suptitle('V13 candidate | All nine families | Identical simulated trends',fontsize=17)
fig.tight_layout(rect=[0,0,1,.96]);save(fig,'01_v13_nine_families_trends')
# Same geometry for all three families isolates colour rather than series style.
fig,axs=plt.subplots(2,3,figsize=(14,7),sharex=True,sharey=True)
for row,v in enumerate([12,13]):
 for col,key in enumerate(['light_hex','medium_hex','dark_hex']):
  ax=axs[row,col]
  for k,fam in enumerate(['Teal','Sky blue','Mint']):
   r=next(r for r in pal[v] if r['family']==fam)
   ax.plot(t,2+k*.8+t*.45,color=r[key],marker='o',lw=2.7,label=fam)
  ax.set_title(f'V{v} | '+['Light','Medium','Dark'][col]);ax.set_xlabel('Time (days)')
  ax.legend(loc='upper left',frameon=False,fontsize=9);ax.set_ylim(1.5,6.6)
fig.suptitle('V12 vs V13 candidate | Teal / Sky blue / Mint\nSame line style for every family to expose colour similarity',fontsize=15)
fig.tight_layout(rect=[0,0,1,.89]);save(fig,'02_v12_vs_v13_teal_skyblue_mint')
print('Created 2 comparison figures, PNG/PDF; V12 default unchanged.')
