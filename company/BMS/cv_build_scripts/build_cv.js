// Build tailored CV (BMS R1608433) mirroring original layout: Times New Roman, bold rule-underlined section heads, US Letter.
const fs = require('fs');
const { Document, Packer, Paragraph, TextRun, AlignmentType, BorderStyle, Footer,
        LevelFormat, TabStopType } = require('docx');

const FONT = 'Times New Roman';
const SZ = 21; // 10.5 pt
const r = (text, o = {}) => new TextRun({ text, font: FONT, size: SZ, ...o });

// Bold the user's own name inside author strings
function authorRuns(s) {
  const out = [];
  const re = /(Zhen Gao|Gao, Zhen)/g;
  let last = 0, m;
  while ((m = re.exec(s))) {
    if (m.index > last) out.push(r(s.slice(last, m.index)));
    out.push(r(m[0], { bold: true }));
    last = m.index + m[0].length;
  }
  if (last < s.length) out.push(r(s.slice(last)));
  return out;
}

const section = (t) => new Paragraph({ keepNext: true,
  spacing: { before: 160, after: 80 },
  border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: '000000', space: 1 } },
  children: [new TextRun({ text: t, font: FONT, size: 22, bold: true })],
});
const para = (children, o = {}) => new Paragraph({ spacing: { after: 40 }, children, ...o });
const bullet = (children) => new Paragraph({ numbering: { reference: 'b', level: 0 }, spacing: { after: 30 }, children });
// job header: dates <tab> title ; second line org
const job = (dates, title, org, place, pb = false) => [
  new Paragraph({ keepNext: true, pageBreakBefore: pb, spacing: { before: 120, after: 0 }, tabStops: [{ type: TabStopType.LEFT, position: 1700 }],
    children: [r(dates), r('\t'), r(title, { bold: true })] }),
  new Paragraph({ keepNext: true, spacing: { after: 40 }, tabStops: [{ type: TabStopType.LEFT, position: 1700 }],
    children: [r(org, { italics: true }), ...(place ? [r('\t'), r(place)] : [])] }),
];
const pub = (authors, title, venue) => new Paragraph({ spacing: { after: 70 },
  children: [...authorRuns(authors), r(' ' + title + ' '), r(venue, { italics: true })] });

const kids = [];
kids.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 20 },
  children: [new TextRun({ text: 'Zhen Gao, PhD', font: FONT, size: 30, bold: true })] }));
kids.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 60 },
  children: [r('Computational Biologist  |  Single-Cell & Spatial Omics  |  Translational AI')] }));
kids.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 },
  children: [r('E-mail: zhen.gao@yahoo.com     Phone: +1 (617) 318-8078')] }));

// ---------- Summary ----------
kids.push(section('Summary'));
kids.push(para([r(
  'Computational biologist with 10+ years of translational omics analysis across pharma (Biogen Translational Data Science), ' +
  'a comprehensive cancer center bioinformatics core and an AI drug-discovery center. Deep, hands-on expertise in single-cell ' +
  'and spatial transcriptomics, carried from QC and cell-type annotation through deconvolution, spatial statistics and ' +
  'decision-ready interpretation. Currently builds LLM-agent analysis workflows in which expert SOPs become machine-executable ' +
  'specifications with built-in validation, so that an agent’s output is checked against the data, not accepted because it is well-formed.')],
  { alignment: AlignmentType.JUSTIFIED }));

// ---------- Core expertise ----------
kids.push(section('Core Expertise'));
const ce = [
  ['Single-cell & spatial omics: ', 'scRNA-seq (Scanpy/scverse, Seurat), integration, annotation, pseudobulk DE; spatial transcriptomics (Visium) – tissue-aware QC, spatially variable genes (Moran’s I, nnSVG), deconvolution (Tangram, RCTD), local spatial statistics (LISA); Squidpy, Voyager.'],
  ['Agentic & AI workflows: ', 'LLM agents (Claude Code, Codex) driven by assay-level specifications; tool-call hooks that enforce analysis and reporting rules with regression tests; AI/ML prediction of drug properties (BBB permeability, ADME).'],
  ['Evaluation of analytical output: ', 'independent cross-method checks, permutation false-positive baselines, swapped-role negative controls, double-run determinism tests, and executable assertions for known silent-failure modes.'],
  ['Translational science: ', 'PK/PD and on/off-target assessment (neurodegeneration), oncology, immunology and IBD patient cohorts, gene therapy (AAV/CRISPR), differential splicing, multi-omics integration.'],
  ['Engineering: ', 'Python, R, Nextflow/nf-core, Git, Linux HPC; reproducible, versioned analyses with archived superseded results for side-by-side comparison.'],
];
ce.forEach(([h, t]) => kids.push(bullet([r(h, { bold: true }), r(t)])));

// ---------- Education ----------
kids.push(section('Education'));
[['PhD', 'Cancer Biology, University of Iowa, IA. ', 'Dec. 2007'],
 ['MS', 'Computer Information Systems, Boston University, MA. ', 'May 2013'],
 ['BS', 'Biopharmaceutics, Nanjing University, China. ', 'Jul. 1999']].forEach(([d, t, y]) =>
  kids.push(new Paragraph({ spacing: { after: 20 }, tabStops: [{ type: TabStopType.LEFT, position: 1700 }],
    children: [r(d), r('\t'), r(t), r(y, { italics: true })] })));

// ---------- Experience ----------
kids.push(section('Work Experience'));
kids.push(...job('02/2026–Current', 'Manager, Principal Scientist AI & Omics', 'Athenomics, LLC (Independent Contractor)', ''));
[
  'Lead end-to-end analysis for a sequencing-plus-analysis service: bulk RNA-seq, scRNA-seq, spatial transcriptomics, WGS (genome-editing and vector-integration verification), differential splicing and shotgun metagenomics, delivered as decision-ready reports.',
  'Built an LLM-agent analysis environment in which each assay’s expert SOP is written as a specification the agent loads before working: approved analysis flow, non-default parameters, known failure modes and executable self-audit assertions. Critical rules are enforced by tool-call hooks backed by a 115-case regression suite.',
  'Every formal analysis starts from a reviewable decision table (question → evidence unit → filters → metrics → permitted conclusions) with a filter-impact audit, mirroring an expert-signed agent specification.',
  'Spatial transcriptomics pilot (Visium): independent cross-checks and double-run tests exposed silent defects that passed every standard check – uninitialized p-values in Squidpy spatial autocorrelation (inflating FDR-significant counts 20–40×), an unseeded random state in Tangram, and an unreliable deconvolution estimate (ρ = −0.01) traced to 15 reference cells.',
  'Benchmarked five differential-splicing methods against ENCODE knockdown ground truth and per-method permutation false-positive baselines (0.1%–18.2%), defining each method’s role in the production workflow.',
  'Run production nf-core pipelines (rnaseq, sarek, taxprofiler, mag) under shared-server resource caps with automated early-failure monitoring.',
].forEach(t => kids.push(bullet([r(t)])));

kids.push(...job('01/2022–10/2023', 'Computational Biology Scientist', 'Translational Data Science Group, BIOGEN Inc.', '', true));
[
  'High-dimensional NGS data analysis across genomics, epigenomics and spatial transcriptomics.',
  'Bulk and single-cell RNA-seq, splicing, proteomics and multi-omics data integration.',
  'On/off-target and PK/PD assessment of novel compounds for neurodegenerative diseases.',
  'Evaluated differential splicing changes induced by a novel gene therapy strategy.',
  'Co-author of scRNASequest, an ecosystem for scRNA-seq analysis, visualization and publishing (BMC Genomics, 2023).',
].forEach(t => kids.push(bullet([r(t)])));

kids.push(...job('10/2016–12/2021', 'Senior Bioinformatics Scientist', 'Biostatistics & Bioinformatics Core, Sylvester Comprehensive Cancer Center, University of Miami', ''));
[
  'Multi-omics data analysis for oncology, inflammatory disease and immunology research, including patient-derived IBD tissue cohorts.',
  'Analysis partner on studies published in Nature Immunology, PNAS, Cancer Research, Cell Reports and Molecular Cancer Therapeutics.',
  'Co-developed methods and R packages for alternative-splicing pathway analysis (PathwaySplice) and differential methylation (coMethDMR).',
].forEach(t => kids.push(bullet([r(t)])));

kids.push(...job('07/2015–07/2016', 'Postdoctoral Associate, Modeling & Simulation', 'Center for AI in Drug Discovery, Case Western Reserve University School of Medicine', ''));
[
  'High-dimensional ADME data mining and computational drug repositioning.',
  'Predicted compound druggability and CNS/blood–brain-barrier permeability with AI/ML approaches (Bioinformatics, 2017).',
].forEach(t => kids.push(bullet([r(t)])));

kids.push(...job('02/2015–07/2015', 'Postdoctoral Associate, Bioinformatics', 'Horae Gene Therapy Center and Viral Vector Core, UMass Chan Medical School', ''));
kids.push(bullet([r('Gene therapy AAV/CRISPR optimization; long-read NGS data analysis.')]));
kids.push(...job('08/2010–04/2012', 'Postdoctoral Associate, Cancer Biology', 'Washington University in St. Louis', ''));
kids.push(bullet([r('miRNA target screening and biomarker discovery.')]));
kids.push(...job('07/2008–07/2010', 'Postdoctoral Fellow, Pharmacology', 'Dept. of Drug Development, Nevada Cancer Institute', ''));
kids.push(bullet([r('Induced cancer senescence by natural products and mechanism.')]));

// ---------- Publications ----------
const P = JSON.parse(fs.readFileSync(__dirname + '/pubs.json', 'utf8'));
kids.push(section('Selected Publications (most relevant to this role)'));
P.selected.forEach(p => kids.push(pub(...p)));
kids.push(section('Additional Publications'));
P.additional.forEach(p => kids.push(pub(...p)));

kids.push(section('Reviewer for Academic Journals'));
kids.push(para([r('Bioinformatics; Journal of Biomedical Informatics; Statistical Methods in Medical Research; BMC Medical Informatics & Decision Making; Journal of Experimental Pharmacology; Bioinformatics and Biology Insights; Current Cancer Drug Targets; Nutrition and Metabolic Insights; Research and Reports in Biology; Biomarkers in Cancer; Cancer Growth and Metastasis; PLOS One.')]));

const doc = new Document({
  creator: 'Zhen Gao',
  styles: { default: { document: { run: { font: FONT, size: SZ } } } },
  numbering: { config: [{ reference: 'b', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•',
    alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 360, hanging: 240 } } } }] }] },
  sections: [{
    properties: { page: { size: { width: 12240, height: 15840 }, margin: { top: 1000, bottom: 1000, left: 1100, right: 1100 } } },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: 'Zhen Gao, PhD  |  zhen.gao@yahoo.com  |  +1 (617) 318-8078', font: FONT, size: 18 })] })] }) },
    children: kids,
  }],
});
Packer.toBuffer(doc).then(b => fs.writeFileSync(process.argv[2], b));
