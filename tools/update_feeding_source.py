"""Build only Feeding/Nutrition evidence from the supplied October 2026 poster.

Coordinates and complete answer units were checked against the rendered PDF.
No other STW's evidence is regenerated. Run validate_feeding_source.py afterward.
"""
import copy
import hashlib
import json
import shutil
from pathlib import Path

import pymupdf
from PIL import Image
from sync_pdf_evidence import locate, normalized, tokens

ROOT = Path(__file__).resolve().parents[1]
DOC = 'Feeding_Nutrition Final 22 Oct 26.pdf'
SHA256 = 'b23f66e90f98f06e5edf27ba9a37d4f7f7fea6bc8cda037683323815d522769e'
# suffix: (PDF points, printed heading, complete source statements, intents)
CARDS = {
    'stability': ((22,177,820,251), 'ASSESS PHYSIOLOGICAL STABILITY FOR ENTERAL FEEDING', [
        'LOOK FOR: Shock / poor perfusion • Recurrent apnoea requiring intervention / respiratory failure • Ongoing seizures with physiological instability • Severe hypothermia • Concerning abdominal signs: bilious vomiting, bloody stools, marked or progressive distension, tenderness or discoloration',
    ], ['criteria','signs','contraindication']),
    'unstable': ((22,268,412,339), 'UNSTABLE / CONTRAINDICATION PRESENT', [
        'Stabilize and treat the cause', 'Start appropriate IV fluids',
        'Reassess clinical stability and readiness to start enteral feeds',
    ], ['management','contraindication']),
    'stable': ((430,268,820,339), 'STABLE / NO FEEDING CONTRAINDICATION', [
        'Start / continue enteral feeds at the earliest',
        'Continue the tolerated feed volume in referred babies',
        'Choose route by gestational maturity and clinical status',
    ], ['management','timing']),
    'fluids': ((22,359,412,466), 'TOTAL DAILY FLUID REQUIREMENT', [
        'ENTERAL + IV + OTHER FLUID INPUTS. Starting guide (mL/kg/day): Use day of life (D), not day of admission',
        'BW <1000 g OR GA <28 wk: D1 80; D2 90; D3 100; D4 120; D5 140; D6 150; D7 150–160',
        'BW ≥1000 g AND GA ≥28 wk: D1 60; D2 80; D3 100; D4 120; D5 140; D6 150; D7 150–160',
    ], ['dose','schedule','management']),
    'iv_type': ((22,465,412,523), 'Maintenance IV fluid type', [
        'First 48 h: 10% dextrose',
        'After 48 h: Review serum Na, urine output and weight change before adding sodium. N/5 in 10% dextrose is an option; adjust for IV volume and enteral intake',
        'KCl: usually 2 mmol/kg/day; review urine output, serum K and other K intake first',
    ], ['dose','timing','management']),
    'iv_review': ((22,541,412,610), 'IV REVIEW → TRANSITION TO FEEDS', [
        'Adjust total fluids and electrolytes as per daily weight change, urine output, blood glucose and clinical status',
        'IV volume = total fluids − feeds − other fluid inputs',
        'Start feeds after stabilization; taper IV as feeds progress; maintain hydration / glucose',
    ], ['management','wean']),
    'milk': ((430,359,820,477), 'MILK SOURCE', [
        'Preferred milk, in order: Mother’s own milk (MOM) → Pasteurized donor human milk → Appropriate formula if human milk unavailable',
        'Start expression within 1 h of birth; repeat every 2–3 h',
        'Use LMU for expression support, safe collection, storage and timely provision of MOM',
        'Colostrum care: Apply mother’s own colostrum to buccal mucosa every 2–4 h when oral feeding is not possible',
    ], ['management','timing','schedule']),
    'route': ((430,489,820,607), 'ROUTE OF FEEDING', [
        '<32 weeks: Orogastric (OG) tube feeds; encourage non-nutritive suckling at the expressed breast when stable',
        '32 to <34 weeks: Spoon/paladai feeds; offer breast',
        '≥34 weeks: Direct breastfeeding; supplement by spoon/paladai if intake is inadequate',
        'Gestation/PMA is a guide. Use OG feeds if breastfeeding or spoon/paladai feeding causes coughing, choking, apnoea/desaturation, excessive fatigue or inadequate intake.',
    ], ['criteria','procedure','management']),
    'standard': ((112,648,348,770), 'STANDARD START', [
        'GA ≥28 wk AND BW ≥1000 g, without antenatal AEDF/REDF',
        'GA ≥35 wk, including antenatal AEDF/REDF†',
        'As soon as possible after birth', '60 mL/kg/day', '20–30 mL/kg/day',
    ], ['criteria','dose','timing']),
    'aedf': ((348,648,584,770), 'CAUTIOUS START: AEDF/REDF', [
        'GA 28–34⁶ wk AND BW ≥1000 g, with antenatal AEDF/REDF',
        'As soon as stable; aim by 12 h', '20 mL/kg/day', '20–30 mL/kg/day',
    ], ['criteria','dose','timing']),
    'small': ((584,648,820,770), 'CAUTIOUS START: VERY SMALL INFANTS', [
        'GA <28 wk OR BW <1000 g', 'As soon as stable; aim by 12 h',
        '10–20 mL/kg/day', '20 mL/kg/day',
    ], ['criteria','dose','timing']),
    'plan_notes': ((22,770,820,825), 'FULL FEEDS', [
        'If BW <1000 g, use the third column irrespective of gestation.',
        '*Start once clinically stable, with reassuring abdominal assessment.',
        '†At ≥35 wk, AEDF/REDF alone does not require restricted feeds or IV fluids; individualize by clinical and abdominal assessment.',
        'FULL FEEDS: usually 150–180 mL/kg/day; individualize to growth and clinical status',
        'FREQUENCY: 2-hourly; consider 3-hourly when PMA >32 wk, stable, on full feeds and off respiratory support',
        'VOLUME PER FEED: daily enteral volume (mL) ÷12 (2-hourly) or ÷8 (3-hourly)',
    ], ['management','dose','schedule']),
    'monitoring': ((22,838,820,978), 'MONITORING', [
        'Before each feed: Clinical condition, vomiting and visible abdominal distension; verify feeding-tube position when used',
        'Daily: Weight change, actual milk intake and urine output; glucose / electrolytes as indicated',
        'Weekly: Plot weight, length and head circumference on INTERGROWTH-21st postnatal growth charts',
        'Immediately if warning signs: Abdominal signs: bilious vomiting, bloody stools, marked/progressive distension, tenderness/discoloration; Any systemic clinical deterioration',
        'Do not routinely check pre-feed gastric residuals or abdominal girth in well babies without signs of feeding intolerance.',
        'Measure girth serially when there is distension or clinical concern.',
    ], ['management','schedule','signs']),
    'poor_gain': ((22,981,820,1034), 'POOR WEIGHT GAIN', [
        'Assess: actual milk intake/transfer, thermal stress, illness, anaemia and possible sodium deficiency',
        'Optimize: correct identified causes; consider 180–200 mL/kg/day if tolerated and no fluid restriction',
        'Review nutrient adequacy: Consider fortification if protein, energy or mineral intake remains insufficient',
    ], ['management','dose']),
    'iron': ((22,1087,820,1125), 'Iron', [
        'Iron: Human-milk-fed preterm OR LBW infants. Elemental iron: BW <1500 g: 2–3 mg/kg/day; BW 1500–2499 g: 2 mg/kg/day. Start at 2 weeks of age once feeds are established. Continue to 6 months, then follow Anemia Mukt Bharat.',
    ], ['dose','timing','criteria']),
    'vitamin_d': ((22,1125,820,1155), 'Vitamin D', [
        'Vitamin D: Consider in human-milk-fed preterm/LBW infants. 400–800 IU/day. As per unit protocol. Start once feeds are established; review at discharge and follow-up.',
    ], ['dose','timing','criteria']),
    'minerals': ((22,1157,820,1197), 'Calcium / phosphorus', [
        'Calcium / phosphorus: Prioritize BW <1500 g OR GA <32 wk on unfortified human milk; others by intake / bone-disease risk. Preterm total intake targets: Ca 120–200; P 70–115 mg/kg/day. Supplement the shortfall. Monitor P / ALP in at-risk infants. Review at term PMA; continue if intake is inadequate or tests remain abnormal.',
    ], ['dose','criteria','management']),
    'supplement_review': ((22,1198,820,1228), 'Count nutrients from milk, fortifier and medicines; avoid duplication.', [
        'Count nutrients from milk, fortifier and medicines; avoid duplication.',
        'Consider Zinc in human-milk-fed preterm or LBW infants.',
    ], ['management','criteria']),
    'dos': ((22,1235,412,1301), 'DOs', [
        'Prioritize mother’s own milk; help mothers express and breastfeed',
        'Start enteral feeds at the earliest; advance rapidly as per tolerance',
        'Review actual intake, growth and total fluids daily',
    ], ['dos']),
    'donts': ((430,1235,820,1301), 'DON’Ts', [
        'Do not delay feeds without a clinical contraindication',
        'Do not routinely check gastric residuals or abdominal girth',
        'Do not overlook bilious vomiting, bloody stools or abdominal signs',
    ], ['donts']),
    'kpis': ((22,1304,820,1395), 'KEY PERFORMANCE INDICATORS (KPIs)', [
        'Timely breastmilk feeding (%): Preterm/LBW neonates requiring facility-based care who received breastmilk within 12 h of birth (inborn) or admission (outborn) / All preterm/LBW neonates requiring facility-based care ×100. Target ≥80%',
        'Exclusive breastmilk feeding at discharge (%): Preterm/LBW neonates admitted to SNCU/NICU who received exclusive breastmilk in the final 24 h before discharge / Eligible preterm/LBW neonates discharged alive from SNCU/NICU ×100. Target ≥90%',
    ], ['kpi']),
    # Full-width banner; it has no separate heading, so the printed line is both.
    'key_message': ((22,1396,820,1418), 'EARLY BREASTMILK FEEDING AND RAPID ADVANCEMENT IMPROVE SURVIVAL AND GROWTH', [
        'EARLY BREASTMILK FEEDING AND RAPID ADVANCEMENT IMPROVE SURVIVAL AND GROWTH',
    ], ['benefit']),
    'related': ((22,1423,820,1510), 'RELATED INFORMATION', [], ['procedure']),
    'abbreviations': ((22,1513,820,1571), 'ABBREVIATIONS', [], ['abbreviation']),
    'references': ((22,1574,820,1613), 'REFERENCES', [], ['reference']),
}

# Keep every plan in one answer unit with its row labels and shared footnotes.
# This prevents a volume from being returned without its population or timing.
for suffix in ('standard', 'aedf', 'small'):
    points,title,parts,intents=CARDS[suffix]
    population='; '.join(parts[:-3])
    statement=(f'{title}. APPLIES TO: {population}. Start time*: {parts[-3]}. '
               f'Start volume: {parts[-2]}. Advance daily as tolerated: {parts[-1]}. '
               + ' '.join(CARDS['plan_notes'][2][:3]))
    CARDS[suffix]=((22,626,820,825),title,[statement],intents)


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf8')


def build_cards(page):
    words = [(t,pymupdf.Rect(w[:4]),round(w[1],1)) for w in page.get_text('words') for t in tokens(w[4])]
    result = []
    for suffix, (points,title,segments,intents) in CARDS.items():
        id = 'feeding_'+suffix
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
        if suffix in ('standard','aedf','small'):
            x0,x1={'standard':(112,348),'aedf':(348,584),'small':(584,820)}[suffix]
            # Only this column, row labels and shared footnotes may match.
            local=[w for w in local if w[1].y0>=770 or w[1].x1<112 or
                   (w[1].x0>=x0 and w[1].x1<=x1)]
        for text in segments or lines:
            boxes,coverage=locate(text,local,rect)
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
        rect=pymupdf.Rect(CARDS[r['id'].removeprefix('feeding_')][0])
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
        save(path,[r for r in original if not (r.get('id') or r.get('chunk_id','')).startswith('feeding_')]+entries)
    path=ROOT/'assets/knowledge_graph/stw_map.json'
    graph=json.loads(path.read_text(encoding='utf8'))
    for r in updated:
        # All headings are printed words; the table heading is split across lines.
        graph['headings'][r['id']]=r['title']
    save(path,graph)
    quote=lambda s:json.dumps(s,ensure_ascii=False).replace('$','\\$')
    content='// Generated by tools/update_feeding_source.py from the pinned supplied PDF.\n'
    content+='const feedingEvidence = <String, List<String>>{\n'
    for r in updated:
        content+='  '+quote(r['id'])+': [\n'+''.join('    '+quote(s['text'])+',\n' for s in r['segments'])+'  ],\n'
    content+='};\n'
    content+='const feedingHeadings = <String, String>{\n'
    content+=''.join('  '+quote(r['id'])+': '+quote(r['title'])+',\n' for r in updated)
    content+='};\n'
    path=ROOT/'lib/features/feeding/domain/feeding_content.dart'
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
    print(f'Built {len(updated)} Feeding/Nutrition cards, crops, graph headings and fallback chunks')


if __name__=='__main__': rebuild()
