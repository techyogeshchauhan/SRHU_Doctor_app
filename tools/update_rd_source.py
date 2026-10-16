#!/usr/bin/env python3
"""Rebuild only RD evidence from the supplied 15-10-26 revision.

The bundled PDF is the source. Coordinates are the visible poster cards in
PDF points; every answer segment is checked against text inside its card.
Other disease entries are preserved. Run from any directory.
"""
import copy
import hashlib
import json
from pathlib import Path
import re
import sys

import pymupdf
from PIL import Image

from sync_pdf_evidence import locate, normalized, tokens

ROOT = Path(__file__).resolve().parents[1]
DOC = 'respiratory_distress_neonates_stw.pdf'
PDF = ROOT / 'assets/pdfs' / DOC
SOURCE_SHA256 = 'ea2d19519976a1ea70b09611be815676096724c1ab00732f2c5ec774dd1890eb'

# Exact outer card coordinates in Respiratory_Distress_STW_Final 15-10-26.pdf.
CARDS = {
    'rd_diagnostic_criteria': (22,187,217,326),
    'rd_immediate_actions': (233,187,820,326),
    'rd_algorithm_overview': (22,340,820,495),
    'rd_initial_preterm_cpap_caffeine': (22,517,532,587),
    'rd_initial_term_moderate_severe_cpap': (22,517,532,587),
    'rd_initial_term_mild_nasal_o2': (550,517,820,587),
    'rd_reassessment_sepsis': (22,603,820,670),
    'rd_improving': (22,686,268,762),
    'rd_not_improving': (550,686,820,782),
    'rd_surfactant_indication': (286,740,532,870),
    'rd_outcome_improving_weaning': (22,771,268,932),
    'rd_outcome_not_improving_optimize_cpap': (550,799,820,932),
    'rd_cpap_failure_referral': (22,949,820,1013),
    'rd_clinical_dos': (22,1019,412,1127),
    'rd_clinical_donts': (430,1019,820,1127),
    'rd_kpis': (22,1139,820,1247),
    'rd_related_information': (22,1312,530,1486),
    'rd_sas_scoring_guide': (544,1312,820,1486),
    'rd_abbreviations': (22,1490,820,1558),
    'rd_references': (22,1566,820,1613),
}

# Keep connected clinical clauses together so a chat excerpt cannot omit
# the population, SpO2 condition, AND criterion, or trial-off condition.
SEGMENTS = {
    'rd_diagnostic_criteria': ['Presence of ANY ONE: RR ≥60/min; Chest retractions; Nasal flaring; Grunting'],
    'rd_immediate_actions': [
        'Apnoea/gasping, poor effort or shock: Stabilize immediately; ventilate when indicated',
        'Maintain TABC; provide warmth; admit to SNCU/NICU',
        'Attach pulse oximeter; monitor HR, RR, SpO₂ and CRT; assess SAS',
        'Feed when stable: breastfeed if mild RD; OG feeds when appropriate on CPAP; decompress stomach',
        'Withhold feeds; give IV fluids for severe RD, recurrent apnoea, poor perfusion or abdominal concerns',
    ],
    'rd_algorithm_overview': [
        'ASSESS GESTATIONAL AGE (GA)* + SILVERMAN–ANDERSEN SCORE (SAS)',
        '*If GA is uncertain, BW ≤1800 g may be used as an operational surrogate',
        'GA ≤34 weeks Any respiratory distress',
        'GA >34 weeks Moderate–severe RD (SAS ≥4)',
        'GA >34 weeks Mild RD (SAS ≤3)',
    ],
    'rd_initial_preterm_cpap_caffeine': [
        'CPAP 5–6 cm H₂O; blended oxygen; titrate FiO₂ to SpO₂ 91–95%',
        'Caffeine citrate for babies <34 weeks requiring respiratory support, as per protocol',
    ],
    'rd_initial_term_mild_nasal_o2': [
        'If SpO₂ <91%: 0.5–1 L/min; Titrate to SpO₂ 91–95%',
    ],
    'rd_reassessment_sepsis': [
        'Monitor SpO₂ continuously while on oxygen/CPAP',
        'Reassess clinical status, SAS and FiO₂ requirement within 15–30 min of starting/changing support',
        'Reassess at least 1 hourly while on respiratory support; immediately if any worsening',
    ],
    'rd_improving': [
        'Decreasing SAS; SpO₂ 91–95% on stable/reducing support; Comfortable breathing',
    ],
    'rd_not_improving': [
        'Persisting/increasing SAS', 'SpO₂ <91% or rising oxygen need',
        'Recurrent apnoea/bradycardia', 'Consider sepsis (Refer to sepsis STW)',
    ],
    'rd_surfactant_indication': [
        'Suspected worsening RDS in a preterm neonate <34 weeks, AND FiO₂ >0.30 on CPAP ≥6 cm H₂O to maintain SpO₂ 91–95%',
        'Give promptly when indicated—before established CPAP failure',
    ],
    'rd_outcome_improving_weaning': [
        'Comfortable breathing; no significant apnoea; low oxygen requirement',
        'Reduce FiO₂, then CPAP as per protocol',
        'Trial off when stable on CPAP 5 cm H₂O and FiO₂ 0.21–0.25',
        'Monitor SpO₂ for 24 h after stopping',
    ],
    'rd_outcome_not_improving_optimize_cpap': [
        'If on Nasal Prongs oxygen, rising oxygen need or distress: Start CPAP',
        'Check prongs, circuit and delivered pressure',
        'Increase CPAP up to 7–8 cm H₂O; Titrate FiO₂',
        'Exclude pneumothorax (Transillumination, X-ray)', 'Consider surfactant',
    ],
    'rd_cpap_failure_referral': [
        'Persistent hypoxaemia/rising FiO₂ despite optimized CPAP, recurrent apnoea, shock or fatigue',
        'Escalate support; intubate/ventilate when indicated; stabilize and refer urgently',
    ],
    'rd_clinical_donts': [
        'Do NOT give unmonitored supplemental oxygen',
        'Do NOT order routine CBC/CRP, chest X-ray or blood gas in uncomplicated mild RD',
        'Do NOT give IV fluids, antibiotics or blood products routinely',
        'Do NOT delay ventilation or referral when CPAP fails',
    ],
    'rd_kpis': [
        'Timely CPAP initiation (%)\nEligible neonates with RD started on CPAP within 30 min of identification\n÷ All neonates with RD meeting the STW criteria for CPAP\n× 100\nTarget >90%',
        'Continuous pulse-oximetry coverage (%)\nNeonates receiving oxygen or CPAP with documented continuous pulse oximetry\n÷ All neonates receiving oxygen or CPAP\n× 100\nTarget >90%',
    ],
}
SEGMENTS['rd_initial_term_moderate_severe_cpap'] = SEGMENTS['rd_initial_preterm_cpap_caffeine']

def load(path): return json.loads(path.read_text(encoding='utf8'))
def save(path,data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def rebuild():
    doc = pymupdf.open(PDF)
    assert len(doc) == 1
    page = doc[0]
    assert 'RR ≥60/min' in page.get_text() and 'EARLY RESCUE SURFACTANT' in page.get_text()
    digest = hashlib.sha256(PDF.read_bytes()).hexdigest()
    assert digest == SOURCE_SHA256, 'Unexpected RD PDF revision: review card coordinates before rebuilding'
    regions_path = ROOT/'assets/regions/regions.json'
    index_path = ROOT/'assets/stw_index/stw_index.json'
    regions, index = load(regions_path), load(index_path)
    existing = {r['id']:r for r in regions}
    words = [(t,pymupdf.Rect(w[:4]),round(w[1],1)) for w in page.get_text('words') for t in tokens(w[4])]
    updated=[]
    for id, points in CARDS.items():
        rect = pymupdf.Rect(points)
        r = copy.deepcopy(existing.get(id,dict(id=id,document=DOC,page=1,type='text',aliases=[],example_questions=[],intents=[])))
        lines = [l.strip().lstrip('•').strip() for l in page.get_text(clip=rect).splitlines()]
        lines = [l for l in lines if l and l != '•']
        heading = lines[0]
        r.update(title=existing.get(id,{}).get('title',heading), section=heading,
                 text='\n'.join(lines),pw=round(page.rect.width,2),ph=round(page.rect.height,2),
                 source_revision='Respiratory_Distress_STW_Final 15-10-26.pdf',source_sha256=digest,
                 x=round(rect.x0/page.rect.width,6),y=round(rect.y0/page.rect.height,6),
                 w=round(rect.width/page.rect.width,6),h=round(rect.height/page.rect.height,6),
                 crop_image=f'assets/regions/crops/{id}.webp')
        r.pop('bounding_boxes',None)
        r['segments'] = []
        for text,header in [(heading,True)]+[(t,False) for t in SEGMENTS.get(id,lines[1:])]:
            # Restrict source matching to this card, even for repeated labels.
            local = [w for w in words if rect.contains((w[1].tl+w[1].br)/2)]
            boxes,coverage=locate(text,local,rect)
            if coverage != 1: raise ValueError((id,text,coverage))
            r['segments'].append(dict(text=text,**({'header':True} if header else {}),bounding_boxes=[normalized(b,page) for b in boxes]))
        r['aliases'] = [a.replace('rr >60','rr ≥60').replace('peep >6','cpap ≥6') for a in r.get('aliases',[]) if not any(old in a.lower() for old in ['4–5','4-5','within 2 hours','loading dose','ventilator cpap'])]
        # The old reassessment card's sepsis content moved to NOT IMPROVING.
        if id == 'rd_reassessment_sepsis':
            r.update(title='Monitoring and Reassessment Intervals', aliases=['monitoring','15–30 min','hourly reassessment','continuous pulse oximetry'],
                     example_questions=['How often should respiratory distress be reassessed?', 'When to reassess after starting CPAP?', 'RD monitoring schedule'],intents=['monitor','schedule'])
        if id == 'rd_not_improving':
            r['aliases'] += ['sepsis in respiratory distress','sepsis consideration']
            r['example_questions'] += ['When should sepsis be considered in respiratory distress?']
        if id == 'rd_surfactant_indication':
            r['aliases'] += ['early rescue surfactant','suspected worsening RDS','cpap ≥6','prompt surfactant']
            r['example_questions'] += ['When should early rescue surfactant be given?', 'Does CPAP 6 meet the surfactant pressure threshold?']
        if id == 'rd_kpis':
            r['aliases'] += ['continuous pulse-oximetry coverage','all neonates meeting CPAP criteria']
        if id == 'rd_references': r['intents']=['reference']
        r['aliases'] = list(dict.fromkeys(r['aliases']))
        r['example_questions'] = list(dict.fromkeys(r.get('example_questions', [])))
        pix=page.get_pixmap(matrix=pymupdf.Matrix(2,2),clip=rect)
        Image.frombytes('RGB',(pix.width,pix.height),pix.samples).save(ROOT/r['crop_image'],format='WEBP',quality=90)
        updated.append(r)
    save(regions_path, updated+[r for r in regions if not r['id'].startswith('rd_')])
    chunks=[]
    for r in updated:
        c=copy.deepcopy(r)
        c.update(chunk_id=r['id'],section_title=r['title'],keywords=r['aliases'],
                 bounding_boxes=[dict(x=r['x'],y=r['y'],width=r['w'],height=r['h'])])
        chunks.append(c)
    save(index_path,chunks+[r for r in index if not (r.get('id') or r.get('chunk_id','')).startswith('rd_')])
    graph_path=ROOT/'assets/knowledge_graph/stw_map.json'
    graph=load(graph_path)
    for r in updated: graph['headings'][r['id']]=r['segments'][0]['text']
    graph['contexts']['rd_initial_term_moderate_severe_cpap'][1]='Moderate–severe RD (SAS ≥4)'
    graph['contexts']['rd_outcome_not_improving_optimize_cpap']=['NOT IMPROVING / WORSENING']
    for link in graph['links']:
        if link['id']=='rd-sepsis': link.update(**{'from':'rd_not_improving','quote':'Consider sepsis (Refer to sepsis STW)'})
        if link['id']=='rd-thermal': link['quote']='provide warmth'
        if link['id']=='rd-feeds': link['quote']='Feed when stable'
    save(graph_path,graph)
    # Keep the standalone Reference tab derived from the same source cards.
    content_path=ROOT/'lib/content/stw_content.dart'
    content=content_path.read_text(encoding='utf8')
    quote=lambda text:json.dumps(text,ensure_ascii=False).replace('$','\\$')
    array=lambda values:'[\n'+''.join('    '+quote(t)+',\n' for t in values)+']'
    values=lambda r:[s['text'] for s in r['segments'] if not s.get('header')]
    by_id={r['id']:r for r in updated}
    text='const rdImmediateActions = '+array(values(by_id['rd_immediate_actions']))+';\n\n'
    text+='const rdReference = [\n'
    reference_order=[by_id['rd_clinical_dos'],by_id['rd_clinical_donts']]+[r for r in updated if r['id'] not in ['rd_clinical_dos','rd_clinical_donts']]
    for r in reference_order:
        if r['id'] in ['rd_initial_term_moderate_severe_cpap','rd_related_information','rd_sas_scoring_guide','rd_immediate_actions','rd_diagnostic_criteria']: continue
        text+='  RefSection('+quote(r['section'])+', '+array(values(r))+(', isDont: true' if r['id']=='rd_clinical_donts' else '')+'),\n'
    text+='];\n\nconst rdRelatedLinks = [\n'+''.join('  RelatedLink('+quote(t)+'),\n' for t in ['Bubble CPAP setup','Fixing binasal prongs','SAS scoring','Surfactant administration'])+'];\n\n'
    start=content.index('const rdImmediateActions =')
    end=content.index('// ---------------------------------------------------------------------------\n// ROP',start)
    content_path.write_text(content[:start]+text+content[end:],encoding='utf8')
    # Maintenance tools must not reintroduce the previous source's segments.
    for filename in ['region_segment_overrides.json','pdf_evidence_overrides.json']:
        path=ROOT/'tools'/filename
        data=load(path)
        data={k:v for k,v in data.items() if not k.startswith('rd_')}
        if filename=='region_segment_overrides.json':
            data.update({r['id']:[{k:v for k,v in s.items() if k!='bounding_boxes'} for s in r['segments']] for r in updated})
        save(path,data)
    print(f'Rebuilt {len(updated)} RD cards, source SHA256 {digest}; other diseases preserved.')

if __name__=='__main__':
    if hasattr(sys.stdout,'reconfigure'): sys.stdout.reconfigure(encoding='utf8')
    rebuild()
