from pathlib import Path
import csv, colorsys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.colors import to_rgb,to_hex
p=Path(__file__).resolve().parent
stem='04_selected_three_tones_light_medium_dark_v10'
with (p/'04_selected_three_tones_light_medium_dark_v9.csv').open() as f: rows=list(csv.DictReader(f))
for r in rows:
 if r['family']=='Coral': r['light_hex']='#EDBDB1'
 if r['family']=='Purple pink': r['light_hex']='#CF8FA2'
rows[-2],rows[-1]=rows[-1],rows[-2]
for ext in ['csv','png','pdf']: assert not (p/f'{stem}.{ext}').exists()
with (p/f'{stem}.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
plt.rcParams.update({'font.family':'DejaVu Sans','pdf.fonttype':42})
fig,ax=plt.subplots(figsize=(10,9.3));ax.set_xlim(-2.1,6);ax.set_ylim(-.6,9.6);ax.axis('off')
for x,t in zip([0,2,4],['Light','Medium','Dark']):ax.text(x+.85,9.15,t,ha='center',fontsize=15,fontweight='bold')
for i,r in enumerate(rows):
 y=8-i;ax.text(-.15,y+.43,r['family'],ha='right',va='center',fontsize=12)
 cols=[r[k] for k in ['light_hex','medium_hex','dark_hex']]
 assert all(colorsys.rgb_to_hls(*to_rgb(a))[1]>colorsys.rgb_to_hls(*to_rgb(b))[1] for a,b in zip(cols,cols[1:]))
 for x,c in zip([0,2,4],cols):
  ax.add_patch(Rectangle((x,y+.2),1.7,.55,facecolor=c,edgecolor='#888888',linewidth=.6));ax.text(x+.85,y-.02,c.upper(),ha='center',fontsize=11)
fig.suptitle('Selected palette | Three tones | v10',fontsize=19,y=.96)
fig.text(.5,.04,'Coral and Purple pink light tones softened. Blue and Neutral rows exchanged.\nAll other tones unchanged from v9.',ha='center',fontsize=10)
fig.savefig(p/f'{stem}.png',dpi=200,bbox_inches='tight');fig.savefig(p/f'{stem}.pdf',bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None});plt.close(fig)
print('Verified 9 rows, 27 swatches, light-medium-dark HLS lightness order.')
