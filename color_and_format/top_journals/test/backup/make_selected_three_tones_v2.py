from pathlib import Path
import csv, colorsys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.colors import to_rgb,to_hex
p=Path(__file__).resolve().parent
stem='04_selected_three_tones_light_medium_dark_v2'
with (p/'04_selected_three_tones_light_medium_dark_v1.csv').open() as f: rows=list(csv.DictReader(f))
changes=[]
for r in rows:
 keys=['dark_hex'] if r['family']=='Teal' else ['medium_hex','dark_hex'] if r['family'] in ['Mint','Purple','Gold','Purple pink'] else []
 for k in keys:
  old=r[k];h,l,s=colorsys.rgb_to_hls(*to_rgb(old));r[k]=to_hex(colorsys.hls_to_rgb(h,l-.035,s));changes.append((r['family'],k,old,r[k]))
for ext in ['csv','png','pdf']: assert not (p/f'{stem}.{ext}').exists()
with (p/f'{stem}.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
plt.rcParams.update({'font.family':'DejaVu Sans','pdf.fonttype':42})
fig,ax=plt.subplots(figsize=(10,8.5));ax.set_xlim(-1.4,6);ax.set_ylim(-.6,8.6);ax.axis('off')
for x,t in zip([0,2,4],['Light','Medium','Dark']):ax.text(x+.85,8.15,t,ha='center',fontsize=15,fontweight='bold')
for i,r in enumerate(rows):
 y=7-i;ax.text(-.15,y+.43,r['family'],ha='right',va='center',fontsize=12)
 cols=[r[k] for k in ['light_hex','medium_hex','dark_hex']]
 assert all(colorsys.rgb_to_hls(*to_rgb(a))[1]>colorsys.rgb_to_hls(*to_rgb(b))[1] for a,b in zip(cols,cols[1:]))
 for x,c in zip([0,2,4],cols):
  ax.add_patch(Rectangle((x,y+.2),1.7,.55,facecolor=c,edgecolor='#888888',linewidth=.6));ax.text(x+.85,y-.02,c.upper(),ha='center',fontsize=11)
fig.suptitle('Selected palette | Three tones | v2',fontsize=19,y=.96)
fig.text(.5,.04,'Teal: darker dark tone. Mint / Purple / Gold / Purple pink: darker medium and dark tones.\nAll light tones unchanged from v1.',ha='center',fontsize=10)
fig.savefig(p/f'{stem}.png',dpi=200,bbox_inches='tight');fig.savefig(p/f'{stem}.pdf',bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None});plt.close(fig)
for c in changes: print(*c)
print('Verified 8 rows in light-medium-dark order; 9 swatches changed.')
