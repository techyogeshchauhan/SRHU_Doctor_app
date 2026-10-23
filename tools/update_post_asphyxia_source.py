"""Pinned PDF-only Post Asphyxia evidence. Does not regenerate other modules."""
import copy
import hashlib
import json
import shutil
from pathlib import Path
import pymupdf
from PIL import Image
from sync_pdf_evidence import locate, normalized, tokens
ROOT = Path(__file__).resolve().parents[1]
DOC = 'Post Asphyxia 16-10-26.pdf'
SHA256 = '6759f46ab811d9bd40267d253117b7ff59691462ad78cfd2dfdcaacffc6071aa'
CARDS = {
'risk': ((22,190,268,265), '1. IDENTIFY RISK', ['Resuscitation • Delayed cry', 'Acute perinatal event', 'Abnormal neurological signs'], ['criteria','signs']),
'stabilize': ((298,190,544,265), '2. STABILIZE', ['Breathing • Perfusion', 'Temperature • Glucose'], ['management']),
'assess': ((574,190,820,265), '3. ASSESS', ['Encephalopathy (Modified Sarnat staging)'], ['procedure','criteria']),
'high_risk': ((22,273,820,297), 'HIGH-RISK FEATURES', ['Apgar ≤5 at 10 min • Still requiring PPV at 10 min • Cord or within 1 h: pH ≤7.1 or base deficit ≥12 mmol/L'], ['criteria','signs']),
'sarnat': ((42,320,800,505), 'ASSESS FOR HYPOXIC ISCHEMIC ENCEPHALOPATHY (HIE): MODIFIED SARNAT STAGING', [], ['criteria','signs','procedure']),
'serial': ((42,505,800,522), 'Record seizures separately', ['Record seizures separately; Repeat serial assessments; Initial normal examination does not exclude evolving HIE'], ['management','schedule']),
'normal': ((22,548,282,632), 'NORMAL EXAMINATION', ['Breastfeed; Skin-to-skin if stable', 'Observe ≥24 h; longer if concerns'], ['management']),
'mild': ((298,548,544,632), 'MILD HIE', ['Supportive care in SNCU/NICU', 'Serial neurological assessments', 'Seizures/worsening: Urgent review/referral'], ['management','refer']),
'urgent': ((560,548,820,632), 'MODERATE / SEVERE HIE OR UNSTABLE', ['Stabilize: Contact referral NICU', 'Arrange urgent transfer for advanced care'], ['management','refer','escalate']),
'oxygen': ((42,668,800,717), 'HR / breathing / SpO₂', ['HR / breathing / SpO₂: Continuous; record hourly. SpO₂ target 91–95% on supplemental oxygen. Ventilation if apnoea / inadequate breathing'], ['management','schedule']),
'perfusion': ((42,717,800,740), 'Perfusion / BP', ['Perfusion / BP: At least hourly initially; more if unstable. Treat shock; avoid indiscriminate fluid boluses'], ['management','schedule']),
'neurological': ((42,740,800,773), 'Neurological status', ['Neurological status: Hourly till 6 h; then 4-hourly for 24–48 h; immediately if worsening. Detect and treat seizures; EEG/aEEG where available'], ['management','schedule']),
 'temperature': ((42,773,800,806), 'Temperature', ['Temperature: Hourly until 6 h; 2-hourly once stable. Aim 36.5–37.0°C (unless under therapeutic hypothermia [TH]); Avoid hyperthermia (>37.5°C)'], ['management','schedule']),
'glucose': ((42,806,800,837), 'Blood glucose', ['Blood glucose: At 1, 2 and 6 h; then 6-hourly once stable. Aim 50–125 mg/dL; correct abnormalities. IV glucose if feeding unsafe'], ['management','schedule']),
'fluids': ((42,837,800,865), 'Fluids / urine output', ['Fluids / urine output: Record intake/output; review balance. Adjust fluids; baseline renal function / electrolytes. Repeat tests; blood gas / calcium as indicated'], ['management','schedule']),
'feeding': ((42,865,800,895), 'Feeding', ['Feeding: Assess alertness, suck–swallow and tolerance. Breast milk when appropriate. Oral feeds when alert and safe'], ['management']),
'seizures': ((22,907,820,956), 'SEIZURES: Act immediately', ['Stabilize airway and breathing → Phenobarbitone 20 mg/kg IV over 15 min (Refer to Seizures STW)', 'Check and correct blood glucose and calcium concurrently; urgent NICU consultation / referral'], ['dose','management','refer']),
'cooling': ((22,967,820,1036), 'THERAPEUTIC HYPOTHERMIA: TIME-CRITICAL REFERRAL', ['Potential candidates: GA ≥36 weeks, moderate/severe HIE + evidence of acute perinatal hypoxia → discuss immediately with referral NICU', 'Confirm strict NNF criteria (scan NNF QR code below); initiate TH ASAP within 6 h of birth', 'TH only in Level III/IV NICUs with adequate intensive care, continuous monitoring and experienced, trained personnel'], ['criteria','management','refer','timing']),
'discharge': ((22,1046,820,1080), 'DISCHARGE', ['Stable • Feeding safely • Family counselled • High-risk Neurodevelopmental follow-up including hearing assessment arranged'], ['followup','management']),
'dos': ((22,1087,412,1189), 'DOs', ['Repeat and document neurological assessments', 'Maintain oxygenation, perfusion, temperature and glucose within target ranges', 'Counsel the family; ensure safe transfer and documented neurodevelopmental follow-up'], ['dos']),
'donts': ((430,1087,820,1189), 'DON’Ts', ['Do not assume an initially normal examination excludes evolving HIE', 'Do not give prophylactic anticonvulsants or unnecessary oxygen/fluid boluses', 'Do not delay TH referral in potentially eligible babies or start unmonitored cooling'], ['donts']),
'kpis': ((22,1201,820,1313), 'KEY PERFORMANCE INDICATORS', ['Timely neurological assessment (%): At-risk neonates with a documented structured neurological assessment within 1 h* / All at-risk neonates ×100. Target >95%. *Within 1 h of birth (inborn) / admission (outborn)', 'Timely physiological assessment (%): Neonates with suspected HIE with complete physiological assessment** within 1 h of admission / All admitted neonates with suspected HIE ×100. Target >95%. **Temperature, glucose, oxygenation and perfusion documented'], ['kpi']),
'related': ((22,1367,820,1479), 'RELATED INFORMATION', ['Modified Sarnat assessment: Examination demonstration video', 'Therapeutic hypothermia: NNF India position statement (2021)'], ['procedure']),
'abbreviations': ((22,1483,820,1549), 'ABBREVIATIONS', [], ['abbreviation']),
'references': ((22,1553,820,1606), 'REFERENCES', [], []),
}
# Preserve each table cell's printed column and row; do not infer a combined stage.
SARNAT = [
 ('Consciousness', ['Hyperalert','Lethargic','Stupor / coma']),
 ('Spontaneous activity', ['Normal / increased','Decreased','Absent']),
 ('Posture', ['Normal','Distal flexion','Decerebrate']),
 ('Tone', ['Normal / increased','Hypotonia','Flaccid']),
 ('Primitive reflexes', ['Suck: normal / incomplete; Moro: exaggerated','Suck: weak; Moro: incomplete','Suck / Moro: absent']),
 ('Autonomic signs', ['Pupils: normal; HR: normal / fast; Breathing: regular','Pupils: constricted; HR: slow; Breathing: periodic / irregular','Pupils: dilated / deviated; HR: variable; breathing: apnoea']),
]
CARDS['sarnat']=(CARDS['sarnat'][0], CARDS['sarnat'][1], [f'{domain}: '+ '; '.join(f'{stage}: {cell}' for stage,cell in zip(['MILD','MODERATE','SEVERE'],cells)) for domain,cells in SARNAT], CARDS['sarnat'][3])

def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf8')


def build_cards(page):
    words = [(t,pymupdf.Rect(w[:4]),round(w[1],1)) for w in page.get_text('words') for t in tokens(w[4])]
    result = []
    for suffix, (points,title,segments,intents) in CARDS.items():
        id = 'post_asphyxia_'+suffix
        rect = pymupdf.Rect(points)
        lines = [s.strip().lstrip('•·').strip().replace('\x00','') for s in page.get_text(clip=rect).splitlines()]
        lines = [s for s in lines if s]
        # Full coherent table statements keep row/column meaning and qualifiers.
        r = dict(id=id,document=DOC,page=1,title=title,section=title,type='text',
                 text=title+'\n'+'\n'.join(segments or lines),aliases=[title.lower()],example_questions=[],
                 intents=intents,source_revision=DOC,source_sha256=SHA256,
                 pw=round(page.rect.width,2),ph=round(page.rect.height,2),
                 x=round(rect.x0/page.rect.width,6),y=round(rect.y0/page.rect.height,6),
                 w=round(rect.width/page.rect.width,6),h=round(rect.height/page.rect.height,6),
                 crop_image=f'assets/regions/crops/{id}.webp',segments=[])
        local=[w for w in words if rect.contains((w[1].tl+w[1].br)/2)]
        _, title_coverage=locate(title,local,rect)
        assert title_coverage==1,(id,'Heading is not printed in this source box')
        for i,text in enumerate(segments or lines):
            candidates=local
            if suffix=='sarnat':
                y0,y1=[(365,383),(384,402),(403,421),(422,440),(440,470),(470,500)][i]
                candidates=[w for w in local if 345 <= w[1].y0 < 364 or y0 <= w[1].y0 < y1]
            boxes,coverage=locate(text,candidates,rect)
            if coverage != 1: raise ValueError((id,text,coverage))
            r['segments'].append(dict(text=text,bounding_boxes=[normalized(b,page) for b in boxes]))
        result.append(r)
    return result


def rebuild():
    pdf=ROOT/'assets/pdfs'/DOC
    source=ROOT.parent/DOC
    if source.exists():
        assert hashlib.sha256(source.read_bytes()).hexdigest()==SHA256
        shutil.copyfile(source,pdf)
    assert hashlib.sha256(pdf.read_bytes()).hexdigest()==SHA256
    doc=pymupdf.open(pdf)
    assert len(doc)==1
    page=doc[0]
    updated=build_cards(page)
    for r in updated:
        rect=pymupdf.Rect(CARDS[r['id'].removeprefix('post_asphyxia_')][0])
        pix=page.get_pixmap(matrix=pymupdf.Matrix(2,2),clip=rect)
        Image.frombytes('RGB',(pix.width,pix.height),pix.samples).save(ROOT/r['crop_image'],format='WEBP',quality=90)
    for filename,index in [('assets/regions/regions.json',False),('assets/stw_index/stw_index.json',True)]:
        path=ROOT/filename
        original=json.loads(path.read_text(encoding='utf8'))
        entries=copy.deepcopy(updated)
        if index:
            for r in entries:
                r.update(chunk_id=r['id'],section_title=r['title'],keywords=r['aliases'],
                         bounding_boxes=[dict(x=r['x'],y=r['y'],width=r['w'],height=r['h'])])
        save(path,[r for r in original if not (r.get('id') or r.get('chunk_id','')).startswith('post_asphyxia_')]+entries)
    path=ROOT/'assets/knowledge_graph/stw_map.json'
    graph=json.loads(path.read_text(encoding='utf8'))
    for r in updated:
        # All headings are printed words; the table heading is split across lines.
        graph['headings'][r['id']]=r['title']
    graph['links']=[l for l in graph['links'] if not l['id'].startswith('post_asphyxia_')]+[
        dict(id='post_asphyxia_seizures_referral',from_='post_asphyxia_seizures',
             to='seizures',kind='refersTo',quote='Refer to Seizures STW',approved=False)
    ]
    graph['links'][-1]['from']=graph['links'][-1].pop('from_')
    save(path,graph)
    quote=lambda s:json.dumps(s,ensure_ascii=False).replace('$','\\$')
    content='// Generated by tools/update_post_asphyxia_source.py from the pinned supplied PDF.\n'
    content+='const postAsphyxiaEvidence = <String, List<String>>{\n'
    for r in updated:
        content+='  '+quote(r['id'])+': [\n'+''.join('    '+quote(s['text'])+',\n' for s in r['segments'])+'  ],\n'
    content+='};\n'
    content+='const postAsphyxiaHeadings = <String, String>{\n'
    content+=''.join('  '+quote(r['id'])+': '+quote(r['title'])+',\n' for r in updated)
    content+='};\n'
    path=ROOT/'lib/features/post_asphyxia/domain/post_asphyxia_content.dart'
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(content,encoding='utf8')
    out=ROOT/'assets/pages'/DOC
    out.mkdir(exist_ok=True)
    pix=page.get_pixmap(matrix=pymupdf.Matrix(1600/page.rect.width,1600/page.rect.width))
    Image.frombytes('RGB',(pix.width,pix.height),pix.samples).save(out/'1.webp',format='WEBP',quality=92)
    path=ROOT/'assets/pages/pages.json'
    pages=json.loads(path.read_text(encoding='utf8'))
    save(path,[p for p in pages if p['document']!=DOC]+[dict(document=DOC,page=1,
        width=pix.width,height=pix.height,pt_width=round(page.rect.width,2),
        pt_height=round(page.rect.height,2),image_path=f'assets/pages/{DOC}/1.webp')])
    print(f'Built {len(updated)} Post Asphyxia cards, crops, graph headings and fallback chunks')


if __name__=='__main__': rebuild()
