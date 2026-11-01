from pathlib import Path
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=Path(__file__).resolve().parent
with (p.parent/'04_selected_three_tones_light_medium_dark_v10.csv').open() as f: rows=list(csv.DictReader(f))
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'pdf.fonttype':42})
rng=np.random.default_rng(101)
data=rng.normal(size=(3,24))*.65+np.array([4,5.1,6.2])[:,None]
labels=['Light','Medium','Dark'];x=np.arange(3);t=np.arange(6)
for i,r in enumerate(rows,1):
 colors=[r[k] for k in ['light_hex','medium_hex','dark_hex']]
 fig,axs=plt.subplots(1,3,figsize=(12,3.8))
 ax=axs[0];ax.bar(x,data.mean(1),yerr=data.std(1,ddof=1)/np.sqrt(24),color=colors,edgecolor='#444444',linewidth=.6,capsize=4,width=.65)
 ax.set_xticks(x,labels);ax.set_ylim(0,8);ax.set_ylabel('Simulated response');ax.set_title('Mean ± SEM (n = 24 / tone)')
 ax=axs[1];bp=ax.boxplot(data.T,positions=x,widths=.55,patch_artist=True,medianprops={'color':'black','linewidth':1.5},showfliers=False)
 for k,(box,c) in enumerate(zip(bp['boxes'],colors)):
  box.set_facecolor(c);box.set_edgecolor('#444444');ax.scatter(k+np.linspace(-.16,.16,24),data[k],c=c,s=17,edgecolors='#444444',linewidth=.4,zorder=3)
 assert sum(len(c.get_offsets()) for c in ax.collections)==72
 ax.set_xticks(x,labels);ax.set_ylim(0,8);ax.set_title('Distribution (all 72 points shown)')
 ax=axs[2]
 for k,(c,ls,m) in enumerate(zip(colors,['-','-.','--'],['o','^','s'])):
  y=2+k*.65+t*(.43+.08*k)+np.sin(t)*.16
  ax.errorbar(t,y,yerr=.18+.025*t,color=c,linestyle=ls,marker=m,linewidth=2,markersize=5,capsize=3,label=labels[k])
 ax.set_xlabel('Time (days)');ax.set_ylim(0,7);ax.set_title('Trend: light solid; dark dashed')
 ax.legend(loc='lower left',bbox_to_anchor=(0,1.11),ncol=3,frameon=False,fontsize=8)
 fig.suptitle(f'V10 | {r["family"]} | '+ ' / '.join(c.upper() for c in colors),fontsize=14,y=1.1)
 fig.text(.5,-.02,'Synthetic data only. Identical data and layout across all 9 families. Tone labels illustrate three comparison conditions.',ha='center',fontsize=9)
 fig.tight_layout()
 stem=f'{i:02d}_{r["family"].lower().replace(" ","_")}_v10_examples'
 for ext in ['png','pdf']:
  target=p/f'{stem}.{ext}';assert not target.exists()
  fig.savefig(target,dpi=180,bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None} if ext=='pdf' else None)
 plt.close(fig)
# Overview uses the actual rendered sheets, without altering originals.
fig,axs=plt.subplots(3,3,figsize=(20,7.5))
for ax,file in zip(axs.flat,sorted(p.glob('*_v10_examples.png'))):
 ax.imshow(plt.imread(file));ax.axis('off')
fig.tight_layout(pad=.5)
fig.savefig(p/'00_overview.png',dpi=180,bbox_inches='tight');fig.savefig(p/'00_overview.pdf',bbox_inches='tight',metadata={'CreationDate':None,'ModDate':None});plt.close(fig)
(p/'README.md').write_text('''# V10 九色系样图

9 套，每套含柱状图、箱线图和折线图；另有 1 张九套总览。均为 PNG/PDF。
色值直接读取 ../04_selected_three_tones_light_medium_dark_v10.csv，不重新调色。
所有色系共用固定 seed=101 的模拟数据。柱状图为 mean ± SEM（standard error of the mean），每档 n=24；箱线图显示全部 72 点，median 黑色；折线为模拟趋势及示意误差范围，不作统计推断。
折线浅色实线、中色点划线、深色虚线，同时采用不同点形。
色卡和各历史版本不作修改。未做色盲模拟验证。
''')
print('9 sheets, 27 panels, 1 overview; 10 PNG and 10 PDF. Box plot point counts verified: 72 per sheet.')
