"""Build Sepsis evidence only from the supplied 15-10-26 PDF revision.

Cards were checked against the rendered poster. Connected conditions remain
together in answer segments. No other disease's evidence is regenerated.
"""
import copy
import hashlib
import json
from pathlib import Path

import pymupdf
from PIL import Image

from sync_pdf_evidence import locate, normalized, tokens

ROOT = Path(__file__).resolve().parents[1]
DOC = 'Sepsis_STW_Final_15-10-26.pdf'
SHA256 = '8ed946d81d7078c33e994a35a95da8b7cb2a7fc9aec19be9671d0319da209927'
# id: (visible card, title, complete semantic segments, retrieval aliases)
CARDS = {
    'assessment': ((64,185,219,354), 'Assess every neonate', [
        'Assess every neonate born in or brought to a health facility for presence of sepsis, at admission and during hospital stay, by looking for red and yellow flag signs and risk factors',
    ], ['screening', 'assessment', 'admission', 'hospital stay']),
    'red_flags': ((257,176,776,301), 'RED FLAGS', [
        'Shock', 'Bleeding from multiple sites',
        'Sclerema – hardened skin over cheeks / thighs',
        'Respiratory distress needing intubation or Silverman’s score >5',
        'If age of baby is less than 72 hours and mother has foul-smelling liquor or chorioamnionitis',
    ], ['red flags', 'shock', 'sclerema', 'intubation', 'Silverman', 'foul-smelling liquor', 'chorioamnionitis']),
    'yellow_signs': ((257,302,776,392), 'YELLOW FLAGS: SIGNS OR MATERNAL RISK FACTORS', [
        'Seizures*', 'Refusal to feed',
        'HR >180 persisting for one hour despite normal temperature',
        'Fast breathing (RR >60/min)', 'Floppiness', 'Lethargy',
        'Feed intolerance', 'New or increased apneic episodes',
        'Fever, or hypothermia <36.0°C not corrected by rewarming',
    ], ['yellow flags', 'signs', 'tachycardia', 'fast breathing', 'temperature', 'hypothermia']),
    'maternal_risks': ((257,396,776,460), 'Any of the maternal risk factors', [
        'Any of the maternal risk factors: If age of baby is less than 3 days (72 hrs) and mother has >3 PV examinations during labour; Rupture of membranes >24 hrs; pPROM; Urinary tract infection; Diarrhea; Fever >38°C',
    ], ['maternal risks', '72 hours', 'PV examinations', 'rupture membranes', 'pPROM', 'urinary tract infection', 'maternal fever']),
    'high_probability': ((66,476,412,770), 'HIGH PROBABILITY OF SEPSIS', [
        'START TREATMENT AND INVESTIGATE',
        'Any RED flag is present',
        'Any two YELLOW flags (signs or maternal risk factors) are present',
        'One YELLOW flag (sign or maternal risk factor) is present AND baby’s gestation at birth is ≤32 weeks or birth weight <1500 g',
        'Admit in the NICU / SNCU',
        'Obtain blood sample for culture and sensitivity (even if baby has received an antibiotic before admission)',
        'Start empirical antibiotics as per local/unit policy, pending reports',
        'Provide supportive care: thermal care, fluids & feeds, glucose monitoring, respiratory & circulatory support',
        'Do labs as indicated (X-ray, CBC, platelets, RBS, electrolytes, renal function)',
        'Perform lumbar puncture (LP) for CSF analysis when baby is hemodynamically stable',
    ], ['high probability', 'indications', 'antibiotics', 'treatment', 'blood culture', 'lumbar puncture', '32 weeks', '1500 g']),
    'observation': ((426,476,775,770), 'AT-RISK / SUSPECT SEPSIS', [
        'OBSERVE',
        'One YELLOW flag (sign or maternal risk factor) is present AND Baby’s gestation at birth is >32 weeks',
        'Keep under close serial observation for 48–72 hrs (monitor 4–6 hourly)',
        'Start antibiotics if another yellow / red sign appears during observation',
        'Obtain sample for blood culture and sensitivity before starting antibiotics (even if baby has received an antibiotic before admission)',
        'Perform LP for CSF analysis if starting antibiotics or if the blood culture is positive',
    ], ['at risk', 'suspect sepsis', 'observation', 'serial observation', '48–72 hours', '4–6 hourly', 'another flag']),
    'seizure': ((66,773,776,792), 'Neonatal seizure', [
        'Neonatal seizure always warrants urgent evaluation for cause (sepsis / meningitis, hypoglycaemia). Keep a low threshold to start antibiotics and perform LP.',
    ], ['seizure', 'urgent evaluation', 'meningitis', 'hypoglycaemia']),
    'review_disappeared': ((66,817,300,904), 'SIGNS OF SEPSIS DISAPPEARED', [
        'Stop antibiotics',
        'Keep under observation till blood culture is reported as sterile after 48 hrs of incubation',
    ], ['48 hour review', 'signs disappeared', 'recovered', 'stop antibiotics']),
    'review_improving': ((304,817,538,904), 'SIGNS OF SEPSIS IMPROVING BUT STILL PRESENT', [
        'Continue antibiotics', 'Antibiotic duration based on blood culture and LP report',
    ], ['48 hour review', 'improving', 'still present', 'continue antibiotics']),
    'review_worsened': ((542,817,776,904), 'SIGNS OF SEPSIS WORSENED, OR A RED FLAG APPEARED AFTER STARTING TREATMENT', [
        'Upgrade antibiotics as per antibiotic local/unit policy',
        'Antibiotic duration based on blood culture and LP report',
    ], ['48 hour review', 'worsened', 'new red flag', 'upgrade antibiotics']),
    'review_day5': ((66,907,776,925), 'review at 5 days', [
        'If antibiotics were continued, review at 5 days. If the baby is now well, the 48-h blood culture is sterile and CSF is normal, stop antibiotics.',
    ], ['5 day review', 'day 5', 'sterile blood culture', 'normal CSF', 'stop antibiotics']),
    'early_stopping': ((66,928,776,943), 'early stopping of antibiotics', [
        'A sterile blood culture at 24–48 h after starting antibiotics supports early stopping of antibiotics.',
    ], ['24–48 hours', 'early stopping', 'sterile culture']),
    'duration': ((66,948,776,1077), 'DURATION OF ANTIBIOTICS', [
        'Pneumonia: 5–7 DAYS',
        'Clinically suspected sepsis AND sterile blood culture AND normal CSF analysis: 5–7 DAYS',
        'Blood culture positive (if asymptomatic by day 5, no meningitis): 7–10 DAYS',
        'Blood culture positive (if remains symptomatic after day 5, no meningitis): 10–14 DAYS',
        'CSF suggestive of meningitis: 21 DAYS',
    ], ['duration', 'pneumonia', 'meningitis', 'blood culture positive', '5–7 days', '7–10 days', '10–14 days', '21 days']),
    'dos': ((66,1081,412,1187), 'DOs', [
        'Start antibiotics within 1 hour if high probability of sepsis is present',
        'Draw blood culture before the first antibiotic dose',
        'Review antibiotics at 48 h against culture, CRP and clinical course',
        'Stop antibiotics if blood culture is sterile and the baby has recovered',
        'Use serial observation and look for non-infective causes of illness',
    ], ['dos', 'good practices', '1 hour', 'before first dose']),
    'donts': ((426,1081,776,1187), 'DON’Ts', [
        'Start antibiotics without an indication – clinical signs in neonates are non-specific',
        'Continue antibiotics for a sterile culture in a baby who has recovered',
        'Act on a positive CRP / procalcitonin in isolation – they are false positive in many non-infective conditions; use to rule out sepsis',
        'Delay LP when it is indicated once the baby is stable',
    ], ['donts', 'avoid', 'CRP', 'procalcitonin', 'antibiotic indication']),
    'kpis': ((66,1198,776,1315), 'KEY PERFORMANCE INDICATORS (KPIs)', [
        'Blood culture before first antibiotic dose (%): Sepsis episodes with blood culture drawn before the first antibiotic dose / Sepsis episodes in which antibiotics were started ×100',
        'Antibiotic initiation within 1 hour (%): Neonates with high probability of sepsis who received the first antibiotic dose within 1 hour of identification / All neonates identified as having high probability of sepsis ×100',
        'Antibiotic exposure during admission (%): Neonates admitted during the reporting period who received at least one dose of a systemic antibiotic during their stay / All neonates admitted during the same reporting period ×100',
    ], ['kpi', 'indicators', 'antibiotic exposure', 'blood culture before first dose']),
    'prevention': ((66,1318,776,1337), 'PREVENT SEPSIS', [
        'PREVENT SEPSIS BY ENSURING HAND HYGIENE, ASEPSIS DURING PROCEDURES AND DILIGENT HOUSEKEEPING',
    ], ['prevention', 'hand hygiene', 'asepsis', 'housekeeping']),
    'related_information': ((66,1343,776,1456), 'RELATED INFORMATION', [], ['hand hygiene video', 'blood culture video', 'lumbar puncture video']),
    'abbreviations': ((66,1458,776,1528), 'ABBREVIATIONS', [], ['abbreviations', 'CBC', 'LP', 'RBS', 'CRP', 'NICU', 'SAS', 'CSF', 'pPROM', 'SNCU']),
    'references': ((66,1530,776,1595), 'REFERENCES', [], ['references', 'source']),
}

def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf8')

def rebuild():
    pdf = ROOT/'assets/pdfs'/DOC
    assert hashlib.sha256(pdf.read_bytes()).hexdigest() == SHA256
    doc = pymupdf.open(pdf)
    assert len(doc) == 1
    page = doc[0]
    words = [(t,pymupdf.Rect(w[:4]),round(w[1],1)) for w in page.get_text('words') for t in tokens(w[4])]
    updated = []
    for suffix, (points,title,segments,aliases) in CARDS.items():
        id = 'sepsis_'+suffix
        rect = pymupdf.Rect(points)
        lines = [s.strip().lstrip('•·').strip() for s in page.get_text(clip=rect).splitlines()]
        lines = [s for s in lines if s]
        r = dict(id=id, document=DOC, page=1, title=title, section=title, type='text',
                 text='\n'.join(lines), aliases=aliases, example_questions=[],
                 intents=({'dos':['dos','timing'], 'donts':['donts','contraindication'],
                           'kpis':['kpi'], 'prevention':['prevention'], 'abbreviations':['abbreviation'],
                           'references':['reference'], 'red_flags':['signs','criteria'],
                           'yellow_signs':['signs'], 'maternal_risks':['criteria'],
                           'duration':['schedule','timing'], 'seizure':['management']}.get(suffix,['management','criteria'])),
                 source_revision=DOC, source_sha256=SHA256,
                 pw=round(page.rect.width,2),ph=round(page.rect.height,2),
                 x=round(rect.x0/page.rect.width,6),y=round(rect.y0/page.rect.height,6),
                 w=round(rect.width/page.rect.width,6),h=round(rect.height/page.rect.height,6),
                 crop_image=f'assets/regions/crops/{id}.webp',segments=[])
        local=[w for w in words if rect.contains((w[1].tl+w[1].br)/2)]
        for text in segments or lines:
            boxes,coverage=locate(text,local,rect)
            if coverage != 1: raise ValueError((id,text,coverage))
            r['segments'].append(dict(text=text,bounding_boxes=[normalized(b,page) for b in boxes]))
        pix=page.get_pixmap(matrix=pymupdf.Matrix(2,2),clip=rect)
        Image.frombytes('RGB',(pix.width,pix.height),pix.samples).save(ROOT/r['crop_image'],format='WEBP',quality=90)
        updated.append(r)
    for filename, index in [('assets/regions/regions.json',False),('assets/stw_index/stw_index.json',True)]:
        path=ROOT/filename
        original=json.loads(path.read_text(encoding='utf8'))
        entries=copy.deepcopy(updated)
        if index:
            for r in entries:
                r.update(chunk_id=r['id'],section_title=r['title'],keywords=r['aliases'],
                         bounding_boxes=[dict(x=r['x'],y=r['y'],width=r['w'],height=r['h'])])
        save(path,[r for r in original if not (r.get('id') or r.get('chunk_id','')).startswith('sepsis_')]+entries)
    path=ROOT/'assets/knowledge_graph/stw_map.json'
    graph=json.loads(path.read_text(encoding='utf8'))
    for r in updated:
        # The heading must be source text, including on cards with no printed heading.
        graph['headings'][r['id']]=r['text'].splitlines()[0] if r['title'] not in ' '.join(r['text'].split()) else r['title']
    save(path,graph)
    quote=lambda s:json.dumps(s,ensure_ascii=False).replace('$','\\$')
    content="// Generated by tools/update_sepsis_source.py from the pinned supplied PDF.\n"
    content+="const sepsisEvidence = <String, List<String>>{\n"
    for r in updated:
        content+='  '+quote(r['id'])+': [\n'+''.join('    '+quote(s['text'])+',\n' for s in r['segments'])+'  ],\n'
    content+='};\n'
    path=ROOT/'lib/features/sepsis/domain/sepsis_content.dart'
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(content,encoding='utf8')
    print(f'Built {len(updated)} Sepsis cards, crops, graph headings and matching fallback chunks')

if __name__ == '__main__': rebuild()
