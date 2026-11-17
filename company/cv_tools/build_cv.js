// Generic CV builder: node build_cv.js <CV_master.json> <version.json> <out.docx>
// master = verified facts (SSOT); version = per-job selection + tailored wording. Layout mirrors the user's original CV.
const fs = require('fs');
const { Document, Packer, Paragraph, TextRun, AlignmentType, BorderStyle, Footer,
        LevelFormat, TabStopType, Table, TableRow, TableCell, WidthType } = require('docx');

const [masterPath, versionPath, outPath] = process.argv.slice(2);
if (!outPath) { console.error('usage: node build_cv.js <CV_master.json> <version.json> <out.docx>'); process.exit(2); }
const M = JSON.parse(fs.readFileSync(masterPath, 'utf8'));
const V = JSON.parse(fs.readFileSync(versionPath, 'utf8'));

const FONT = 'Times New Roman', SZ = 21; // 10.5 pt
const r = (text, o = {}) => new TextRun({ text, font: FONT, size: SZ, ...o });
function authorRuns(s) {               // bold the user's own name inside author strings
  const out = []; const re = /(Zhen Gao|Gao, Zhen)/g; let last = 0, m;
  while ((m = re.exec(s))) {
    if (m.index > last) out.push(r(s.slice(last, m.index)));
    out.push(r(m[0], { bold: true })); last = m.index + m[0].length;
  }
  if (last < s.length) out.push(r(s.slice(last)));
  return out;
}
const section = (t) => new Paragraph({ keepNext: true, spacing: { before: 160, after: 80 },
  border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: '000000', space: 1 } },
  children: [new TextRun({ text: t, font: FONT, size: 22, bold: true })] });
const bullet = (children) => new Paragraph({ numbering: { reference: 'b', level: 0 }, spacing: { after: 30 }, children });
const TAB = [{ type: TabStopType.LEFT, position: 1700 }];
const job = (j, pb) => [
  new Paragraph({ keepNext: true, pageBreakBefore: !!pb, spacing: { before: 120, after: 0 }, tabStops: TAB,
    children: [r(j.dates), r('\t'), r(j.title, { bold: true })] }),
  new Paragraph({ keepNext: true, spacing: { after: 40 }, tabStops: TAB, children: [r(j.org, { italics: true })] }),
];
const pub = (p) => new Paragraph({ spacing: { after: 70 },
  children: [...authorRuns(p.authors), r(' ' + p.title + ' '), r(p.venue, { italics: true })] });

// ---- lookups with hard failure on unknown ids (a typo must not silently drop content) ----
const jobById = Object.fromEntries(M.jobs.map(j => [j.id, j]));
const pubById = Object.fromEntries(M.publications.map(p => [p.id, p]));
function need(map, id, kind) { if (!map[id]) throw new Error(`unknown ${kind} id: ${id}`); return map[id]; }

const kids = [];
kids.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 20 },
  children: [new TextRun({ text: M.name, font: FONT, size: 30, bold: true })] }));
kids.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 60 }, children: [r(V.headline)] }));
kids.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 },
  children: [r(`E-mail: ${M.contact.email}     Phone: ${M.contact.phone}`)] }));

kids.push(section('Summary'));
V.summary.forEach(t => kids.push(bullet([r(t)])));

kids.push(section('Core Expertise'));
V.core_expertise.forEach(([h, t]) => kids.push(bullet([r(h, { bold: true }), r(t)])));

kids.push(section('Education'));
M.education.forEach(e => kids.push(new Paragraph({ spacing: { after: 20 }, tabStops: TAB,
  children: [r(e.degree), r('\t'), r(e.field + ' '), r(e.date, { italics: true })] })));

kids.push(section('Work Experience'));
V.jobs.forEach(vj => {
  const j = need(jobById, vj.id, 'job');
  kids.push(...job(j, vj.page_break_before));
  const bmap = Object.fromEntries(j.bullets.map(b => [b.id, b.text]));
  vj.bullets.forEach(bid => kids.push(bullet([r(need(bmap, bid, `bullet in ${j.id}`))])));
});

// publications: selected (in version order) then all remaining in master order -> nothing can be dropped
const sel = V.selected_publications.map(id => need(pubById, id, 'publication'));
const selSet = new Set(V.selected_publications);
kids.push(section(V.selected_publications_title || 'Selected Publications'));
sel.forEach(p => kids.push(pub(p)));
const rest = M.publications.filter(p => !selSet.has(p.id));
if (rest.length) { kids.push(section('Additional Publications')); rest.forEach(p => kids.push(pub(p))); }

kids.push(section('Reviewer for Academic Journals'));
const J = M.reviewer_journals, half = Math.ceil(J.length / 2), COLW = 5020;
const NB = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
const noB = { top: NB, bottom: NB, left: NB, right: NB };
const cell = (t) => new TableCell({ width: { size: COLW, type: WidthType.DXA }, borders: noB,
  children: t ? [bullet([r(t)])] : [new Paragraph('')] });
kids.push(new Table({ width: { size: COLW * 2, type: WidthType.DXA }, columnWidths: [COLW, COLW],
  borders: { ...noB, insideHorizontal: NB, insideVertical: NB },
  rows: Array.from({ length: half }, (_, i) => new TableRow({ children: [cell(J[i]), cell(J[i + half])] })) }));

const doc = new Document({
  creator: M.name.replace(/, PhD$/, ''),
  styles: { default: { document: { run: { font: FONT, size: SZ } } } },
  numbering: { config: [{ reference: 'b', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•',
    alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 360, hanging: 240 } } } }] }] },
  sections: [{
    properties: { page: { size: { width: 12240, height: 15840 }, margin: { top: 1000, bottom: 1000, left: 1100, right: 1100 } } },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: `${M.name}  |  ${M.contact.email}  |  ${M.contact.phone}`, font: FONT, size: 18 })] })] }) },
    children: kids,
  }],
});
Packer.toBuffer(doc).then(b => fs.writeFileSync(outPath, b));
