"""Pinned PDF-only Neonatal Jaundice evidence. Does not regenerate other modules.

Source: DHR STW "Neonatal Jaundice in infants >= 35 weeks" (July 2020).
Every heading and segment below is printed in the PDF box it belongs to;
build_cards() fails when a word is not found there. Spelling is kept as
printed (e.g. "ASSESMENT", "Peipheral").
"""
import copy
import hashlib
import json
import shutil
import sys
from pathlib import Path
import pymupdf
from PIL import Image
from sync_pdf_evidence import locate, normalized, tokens
ROOT = Path(__file__).resolve().parents[1]
DOC = 'Neonatal Jaundice.pdf'
SHA256 = '19aadebc9175451e411416f50a78a2c2009116208205082a12ccdd978f46ac12'
CARDS = {
'scope': ((118,106,724,192), 'NEONATAL JAUNDICE IN INFANTS ≥ 35 WEEKS', ['Standard Treatment Workflow (STW)', 'NEONATAL JAUNDICE IN INFANTS ≥ 35 WEEKS', 'ICD-10-P59.9'], ['definition','criteria']),
'visual': ((250,218,485,462), 'VISUAL ASSESMENT', ['Examine the baby in bright natural/ white fluorescent light', 'Make sure the baby is naked and no yellow/ off white background', 'Examine blanched skin', 'Assess severity of jaundice'], ['procedure','signs']),
'risk_factors': ((490,250,822,474), 'LOOK FOR THESE RISK FACTORS', ['Gestation < 38 weeks', 'Previous sibling requiring treatment for jaundice', 'Blood group incompatibility (ABO/Rh)', 'High prevalence of G6PD deficiency', 'Exclusively breast fed baby with weight loss >3% per day; or >10% cumulative', 'Total serum bilirubin (TSB) / Transcutaneous bilirubin (TcB) value in the high/ high-intermediate risk zone'], ['criteria','prevention']),
'kramer': ((10,535,520,680), 'KRAMER ZONES', ['Clinical examination every 12 hrs during the initial 3 to 5 days of life; use TcB if available', '1 Face and neck: 4 to 6 mg/dL', '2 Chest and upper abdomen: 8 to 10 mg/dL', '3 Lower abdomen and thighs: 12 to 14 mg/dL', '4 Legs and arms/ forearms: 15 to 18 mg/dL', '5 Palms and soles: >15 to 20 mg/dL'], ['criteria','signs','schedule','procedure']),
'serious': ((606,532,840,680), 'SERIOUS JAUNDICE', ['Visible jaundice in first 24 hrs OR', 'Yellow palms and soles anytime OR', 'Signs of acute bilirubin encephalopathy (ABE) like poor suck/feeding, lethargy, hypotonia OR', 'Abnormal posturing such as arching, retrocollis, opisthotonus, convulsion, fever, high pitched cry'], ['criteria','signs','definition']),
'start_pt': ((62,785,446,852), 'Start Intensive Phototherapy', ['Start Intensive Phototherapy', 'Document serum bilirubin simultaneously', 'Prepare for exchange blood transfusion (EBT) if signs of ABE are present'], ['management','escalate']),
'needs_tsb': ((518,785,818,892), 'Does the infant require TSB measurement ?', ['Jaundice in first 24 hrs ?', 'Beyond 24 hrs: more than 12-14 mg/dL on visual assessment / TcB or near PT cut-off ?', 'Unsure about visual assessment ?'], ['criteria','procedure']),
'tsb_cutoff': ((108,865,428,906), 'As per TSB, determine if baby requires phototherapy/ EBT if TSB at/more than cut-off?', ['As per TSB, determine if baby requires phototherapy/ EBT if TSB at/more than cut-off?'], ['criteria','management']),
'above_cutoff': ((50,936,442,973), 'Continue phototherapy/prepare for EBT and determine the cause', ['Continue phototherapy/prepare for EBT and determine the cause'], ['management']),
'investigation': ((30,976,366,1035), 'Investigation:', ["Blood type and DCT (if mother is 'O' or Rh -ve", 'G6PD status', 'Peipheral smear and reticulocyte count'], ['procedure','management']),
'below_cutoff': ((386,966,514,996), 'Stop phototherapy', ['Stop phototherapy'], ['stop','management']),
'stop_pt': ((30,1037,362,1076), 'Stop phototherapy', ['TSB falls below 13-14 mg/dL or 2 mg/dL below cut-off'], ['stop','criteria']),
'continue_visual': ((656,928,812,1012), 'Continue visual assessment/TcB (if available) every 12 to 24 hrs till discharge', ['Continue visual assessment/TcB (if available) every 12 to 24 hrs till discharge'], ['schedule','management']),
'optimal_pt': ((25,1083,432,1262), 'ENSURING OPTIMAL PHOTOTHERAPY', ['Keep the baby naked (only small nappy to cover the genitalia and eye covers)', 'Place the baby close to the lights', 'Phototherapy can be interrupted for feeding & clinical procedures', 'Encourage frequent breastfeeding', 'Monitor temperature regularly', 'Maintain equipment as per manufacturer’s instructions', 'Frequency of repeat TSB measurement depends on cause, severity, age and gestation', 'Hemolytic jaundice : 6 to 8 hourly during initial 24 to 48 hrs', 'Non-hemolytic jaundice : 12-24 hourly'], ['procedure','management','schedule']),
'optimal_ebt': ((436,1072,650,1250), 'ENSURING OPTIMAL EXCHANGE BLOOD TRANSFUSION (EBT)', ['Immediate EBT is recommended if infant shows signs of ABE or if TSB is above the recommended age and risk specific cut off', 'Exchange volume = Twice the estimated blood volume of 80-100 mL/kg'], ['criteria','procedure','dose','escalate']),
'discharge': ((655,1082,836,1210), 'DISCHARGE ADVICE', ['Reinforce breastfeeding at discharge', 'If discharged before 72 hrs; follow up at 48 to 72 hrs after discharge'], ['followup','management']),
'dos': ((22,1264,345,1394), 'SOME IMPORTANT DO’S', ['Encourage frequent breastfeeding', 'Avoid exposure to naphthalene balls', 'Complete evaluation of newborn is important to evaluate for risk factors and underlying causes', 'Do pre-discharge risk assessment'], ['dos']),
'donts': ((350,1264,822,1394), 'SOME IMPORTANT DON’TS', ['Sunlight should not be used for treatment of hyperbilirubinemia', 'Do not rely on visual assessment/ TcB while the baby is under phototherapy', 'Do not give phenobarbitone for treatment of hyperbilirubinemia', 'Do not stop breastfeeding'], ['donts']),
'abbreviations': ((15,1392,826,1460), 'ABBREVIATIONS', ['ABE: Acute bilirubin encephalopathy', 'DCT: Direct coombs test', 'EBT: Exchange blood transfusion', 'G6PD: Glucose-6-phosphate dehydrogenase', 'TcB: Transcutaneous bilirubin', 'TSB: Total serum bilirubin'], ['abbreviation']),
'references': ((10,1462,826,1556), 'REFERENCES', ['1. Screening, Prevention and Management of Neonatal Hyperbilirubinemia. Clinical Practice Guidelines. National Neonatology Forum India 2020. www.nnfi.org/cpg', '2.Management of hyperbilirubinemia in the newborn infant 35 or more weeks of gestation. American Academy of Pediatrics Practice Guidelines . www.cdc.gov'], []),
# Full-width banner; it has no separate heading, so the printed line is both.
'key_message': ((200,1555,642,1580), 'HYPERBILIRUBINEMIA IS A PREVENTABLE CAUSE OF BRAIN DAMAGE', ['HYPERBILIRUBINEMIA IS A PREVENTABLE CAUSE OF BRAIN DAMAGE'], ['benefit','prevention']),
}
ALIASES = {
'kramer': ['kramer zones', 'kramer zone', 'visual assessment of jaundice', 'approx serum bilirubin'],
'serious': ['serious jaundice', 'severe jaundice', 'acute bilirubin encephalopathy', 'yellow palms and soles'],
'start_pt': ['intensive phototherapy', 'start phototherapy'],
'needs_tsb': ['tsb measurement', 'serum bilirubin measurement', 'when to measure tsb'],
'tsb_cutoff': ['phototherapy cut-off', 'tsb cut-off'],
'investigation': ['jaundice investigations', 'dct', 'g6pd', 'reticulocyte count'],
'stop_pt': ['stop phototherapy', 'stopping phototherapy'],
'optimal_pt': ['optimal phototherapy', 'repeat tsb frequency'],
'optimal_ebt': ['exchange blood transfusion', 'exchange transfusion', 'ebt volume'],
'continue_visual': ['visual assessment frequency', 'tcb monitoring'],
'risk_factors': ['jaundice risk factors', 'risk factors for hyperbilirubinemia'],
}


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf8')


def build_cards(page):
    words = [(t,pymupdf.Rect(w[:4]),round(w[1],1)) for w in page.get_text('words') for t in tokens(w[4])]
    result = []
    for suffix, (points,title,segments,intents) in CARDS.items():
        id = 'jaundice_'+suffix
        rect = pymupdf.Rect(points)
        r = dict(id=id,document=DOC,page=1,title=title,section=title,type='text',
                 text=title+'\n'+'\n'.join(s for s in segments if s != title),
                 aliases=[title.lower(), *ALIASES.get(suffix, [])],example_questions=[],
                 intents=intents,source_revision=DOC,source_sha256=SHA256,
                 pw=round(page.rect.width,2),ph=round(page.rect.height,2),
                 x=round(rect.x0/page.rect.width,6),y=round(rect.y0/page.rect.height,6),
                 w=round(rect.width/page.rect.width,6),h=round(rect.height/page.rect.height,6),
                 crop_image=f'assets/regions/crops/{id}.webp',segments=[])
        local=[w for w in words if rect.contains((w[1].tl+w[1].br)/2)]
        _, title_coverage=locate(title,local,rect)
        assert title_coverage==1,(id,'Heading is not printed in this source box')
        for text in segments:
            boxes,coverage=locate(text,local,rect)
            if coverage != 1: raise ValueError((id,text,coverage))
            r['segments'].append(dict(text=text,bounding_boxes=[normalized(b,page) for b in boxes]))
        result.append(r)
    return result


def rebuild(check_only=False):
    pdf=ROOT/'assets/pdfs'/DOC
    source=ROOT.parent/'Pdfs'/DOC
    if source.exists() and not check_only:
        assert hashlib.sha256(source.read_bytes()).hexdigest()==SHA256
        shutil.copyfile(source,pdf)
    path_used = pdf if pdf.exists() else source
    assert hashlib.sha256(path_used.read_bytes()).hexdigest()==SHA256
    doc=pymupdf.open(path_used)
    assert len(doc)==1
    page=doc[0]
    updated=build_cards(page)
    if check_only:
        print(f'All {len(updated)} Jaundice cards located verbatim')
        return
    for r in updated:
        rect=pymupdf.Rect(CARDS[r['id'].removeprefix('jaundice_')][0])
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
        save(path,[r for r in original if not (r.get('id') or r.get('chunk_id','')).startswith('jaundice_')]+entries)
    path=ROOT/'assets/knowledge_graph/stw_map.json'
    graph=json.loads(path.read_text(encoding='utf8'))
    for r in updated:
        graph['headings'][r['id']]=r['title']
    save(path,graph)
    quote=lambda s:json.dumps(s,ensure_ascii=False).replace('$','\\$')
    content='// Generated by tools/update_jaundice_source.py from the pinned supplied PDF.\n'
    content+='const jaundiceEvidence = <String, List<String>>{\n'
    for r in updated:
        content+='  '+quote(r['id'])+': [\n'+''.join('    '+quote(s['text'])+',\n' for s in r['segments'])+'  ],\n'
    content+='};\n'
    content+='const jaundiceHeadings = <String, String>{\n'
    content+=''.join('  '+quote(r['id'])+': '+quote(r['title'])+',\n' for r in updated)
    content+='};\n'
    path=ROOT/'lib/features/jaundice/domain/jaundice_content.dart'
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
    print(f'Built {len(updated)} Jaundice cards, crops, graph headings and fallback chunks')


if __name__=='__main__': rebuild(check_only='--check' in sys.argv)
