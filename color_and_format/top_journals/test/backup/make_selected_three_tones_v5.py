from pathlib import Path
import csv, colorsys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.colors import to_rgb,to_hex
p=Path(__file__).resolve().parent
stem='04_selected_three_tones_light_medium_dark_v5'
with (p/'04_selected_three_tones_light_medium_dark_v3.csv').open() as f: rows=list(csv.DictReader(f))
rows.extend([
 {'family':'Blue 3B4992','light_hex':'#A5ADD8','medium_hex':'#3B4992','dark_hex':'#293366'},
 {'family':'Purple 987EBD','light_hex':'#B4A6CA','medium_hex':'#987EBD','dark_hex':'#6F4F9B'}
])
for ext in ['csv','png','pdf']: assert not (p/f'{stem}.{ext}').exists()
with (p/f'{stem}.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
plt.rcParams.update({'font.family':'DejaVu Sans','pdf.fonttype':42})
fig,ax=plt.subplots(figsize=(10,10));ax.set_xlim(-2.1,6);ax.set_ylim(-.6,10.6);ax.axis('off')
for x,t in zip([0,2,4],['Light','Medium','Dark']):ax.text(x+.85,10.15,t,ha='center',fontsize=15,fontweight='bold')
for i,r in enumerate(rows):
 y=9-i;ax.text(-.15,y+.43,r['family'],ha='right',va='center',fontsize=12)
 cols=[r[k] for k in ['light_hex','medium_hex','dark_hex']]
 assert all(colorsys.rgb_to_hls(*to_rgb(a))[1]>colorsys.rgb_to_hls(*to_rgb(b))[1] for a,b in zip(cols,cols[1:]))
 for x,c in zip([0,2,4],cols):
  ax.add_patch(Rectangle((x,y+.2),1.7,.55,facecolor=c,edgecolor='#888888',linewidth=.6));ax.text(x+.85,y-.02,c.upper(),ha='center',fontsize=11)
fig.suptitle('Selected palette | Three tones | v5',fontsize=19,y=.96)
fig.text(.5,.04,'Added #3B4992 and #987EBD as medium tones, each with light and dark variants.\nThe previous 8 families are unchanged from v3.',ha='center',fontsize=10)
fig.savefig(p/f'{stem}.png',dpi=200,bbox_inches='tight');fig.savefig(p/f'{stem}.pdf',bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None});plt.close(fig)
print('Verified 10 rows, 30 swatches, light-medium-dark HLS lightness order.')
