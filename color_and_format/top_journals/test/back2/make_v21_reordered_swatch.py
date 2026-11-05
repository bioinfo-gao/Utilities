from pathlib import Path
import csv
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
p=Path(__file__).resolve().parent
with (p/'04_selected_three_tones_light_medium_dark_v21.csv').open() as f:rows={r['family']:r for r in csv.DictReader(f)}
with (p.parent/'v21_family_order.csv').open() as f:order=[r['family'] for r in csv.DictReader(f)]
assert len(order)==10 and set(order)==set(rows)
plt.rcParams.update({'font.family':'DejaVu Sans','pdf.fonttype':42})
fig,ax=plt.subplots(figsize=(10,10.2));ax.set_xlim(-2.1,6);ax.set_ylim(-.6,10.6);ax.axis('off')
for x,t in zip([0,2,4],['Light','Medium','Dark']):ax.text(x+.85,10.15,t,ha='center',fontsize=15,fontweight='bold')
for i,name in enumerate(order):
 r=rows[name];y=9-i;ax.text(-.15,y+.43,name,ha='right',va='center',fontsize=12)
 for x,k in zip([0,2,4],['light_hex','medium_hex','dark_hex']):
  c=r[k];ax.add_patch(Rectangle((x,y+.2),1.7,.55,facecolor=c,edgecolor='#888888',linewidth=.6));ax.text(x+.85,y-.02,c.upper(),ha='center',fontsize=11)
fig.suptitle('Selected palette | Three tones | V21',fontsize=19,y=.96)
fig.text(.5,.04,'Default selection order: alternating cool / warm families; Neutral last.\nAll V21 colour values unchanged. Light / Medium / Dark.',ha='center',fontsize=10)
for ext in ['png','pdf']:
 target=p/f'04_selected_three_tones_light_medium_dark_v21_cool_warm_order.{ext}';assert not target.exists()
 fig.savefig(target,dpi=220,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
print('10 families, 30 original colour values; display order matches canonical family order.')
