from pathlib import Path
import csv, colorsys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.colors import to_rgb,to_hex
p=Path(__file__).resolve().parent
stem='04_selected_three_tones_light_medium_dark_v1'
for ext in ['csv','png','pdf']:
 assert not (p/f'{stem}.{ext}').exists(), 'Output already exists'
with (p/'palette_pairs.csv').open() as f: source=list(csv.DictReader(f))
rows=[]
for r in source:
 if r['scheme']=='03_Cell_reference' and r['name']!='Blue grey':
  mid=r['reference_hex']
  if r['name']=='Mint':
   h,l,s=colorsys.rgb_to_hls(*to_rgb(mid));mid=to_hex(colorsys.hls_to_rgb(h,l-.055,s))
  rows.append([r['name'],r['light_hex'],mid,r['dark_hex']])
for name in ['Purple pink','Neutral']:
 r=next(r for r in source if r['scheme']=='01_Nature_reference' and r['name']==name)
 rows.append([name,r['light_hex'],r['reference_hex'],r['dark_hex']] if name!='Neutral' else [name,r['light_hex'],r['dark_hex'],r['reference_hex']])
with (p/f'{stem}.csv').open('w') as f:
 w=csv.writer(f);w.writerow(['family','light_hex','medium_hex','dark_hex']);w.writerows(rows)
plt.rcParams.update({'font.family':'DejaVu Sans','pdf.fonttype':42})
fig,ax=plt.subplots(figsize=(10,8.5));ax.set_xlim(-1.4,6);ax.set_ylim(-.6,8.6);ax.axis('off')
for x,t in zip([0,2,4],['Light','Medium','Dark']):ax.text(x+.85,8.15,t,ha='center',fontsize=15,fontweight='bold')
for i,(name,*cols) in enumerate(rows):
 y=7-i
 ax.text(-.15,y+.43,name,ha='right',va='center',fontsize=12)
 for x,c in zip([0,2,4],cols):
  ax.add_patch(Rectangle((x,y+.2),1.7,.55,facecolor=c,edgecolor='#888888',linewidth=.6))
  ax.text(x+.85,y-.02,c.upper(),ha='center',fontsize=11)
fig.suptitle('Selected palette | Three tones',fontsize=19,y=.96)
fig.text(.5,.04,'Cell first 6 families + Nature Purple pink + Neutral\nMint medium: #8FD694 → '+rows[3][2].upper()+'; other swatches retained.',ha='center',fontsize=11)
fig.savefig(p/f'{stem}.png',dpi=200,bbox_inches='tight')
fig.savefig(p/f'{stem}.pdf',bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None})
plt.close(fig)
for name,*cols in rows:
 lum=[colorsys.rgb_to_hls(*to_rgb(c))[1] for c in cols]
 assert lum[0]>lum[1]>lum[2], (name,lum)
print('8 rows, 24 swatches; light > medium > dark HLS lightness verified.')
print('Mint medium:',rows[3][2])
