from pathlib import Path
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import to_rgb
p=Path(__file__).resolve().parent
with (p.parent/'04_selected_three_tones_light_medium_dark_v12.csv').open() as f: rows=list(csv.DictReader(f))
def luminance(c):
 v=np.array(to_rgb(c));v=np.where(v<=.04045,v/12.92,((v+.055)/1.055)**2.4)
 return float(v@[.2126,.7152,.0722])
def median_color(c):
 l=luminance(c)
 return '#FFFFFF' if 1.05/(l+.05)>(l+.05)/.05 else '#000000'
rng=np.random.default_rng(101);data=rng.normal(size=(3,24))*.65+np.array([4,5.1,6.2])[:,None]
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.spines.top':False,'axes.spines.right':False,'pdf.fonttype':42})
fig,axs=plt.subplots(9,2,figsize=(10,22),sharex=True,sharey=True)
report=[]
for i,r in enumerate(rows):
 cs=[r[k] for k in ['light_hex','medium_hex','dark_hex']]
 for j,ax in enumerate(axs[i]):
  bp=ax.boxplot(data.T,positions=[0,1,2],widths=.6,patch_artist=True,showfliers=False,medianprops={'linewidth':2.2,'color':'black','zorder':5})
  for k,(box,c) in enumerate(zip(bp['boxes'],cs)):
   box.set_facecolor(c);box.set_edgecolor('#333333')
   mc='#000000' if j==0 else median_color(c)
   bp['medians'][k].set_color(mc)
   if j==1: report.append([r['family'],['light','medium','dark'][k],c,mc])
  ax.set_ylim(2,8.2);ax.set_xticks([0,1,2],['Light','Medium','Dark']);ax.tick_params(labelbottom=True)
  ax.set_title(r['family']+(' | all black' if j==0 else ' | contrast-based black / white'),loc='left',fontsize=10)
  if j==0:ax.set_ylabel('Simulated response')
fig.suptitle('V12 median-line comparison\nLeft: black medians    Right: higher-contrast black or white medians',fontsize=14,y=.997)
fig.text(.5,.005,'Synthetic data (24 observations per box). Only median colour changes; fills, data, whiskers and axes are identical.\nBlack/white chosen by higher sRGB luminance contrast against each fill; this is not a universal rule for every plotted line.',ha='center',fontsize=9)
fig.tight_layout(rect=[0,.025,1,.975],h_pad=1.4)
for ext in ['png','pdf']:
 f=p/f'v12_all_families_median_comparison.{ext}';assert not f.exists();fig.savefig(f,dpi=160,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
plt.close(fig)
with (p/'median_line_colors.csv').open('w') as f:
 w=csv.writer(f);w.writerow(['family','tone','fill','median']);w.writerows(report)
print('9 families, 18 panels; 27 median colour decisions saved.')
for r in report:
 if r[-1]=='#FFFFFF':print('White:',*r[:3])
