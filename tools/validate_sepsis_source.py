"""Verify source identity, complete card text, segment geometry and crops.

Optional baseline folder contains pre-change regions.json, stw_index.json,
stw_map.json and baseline.json; prove other diseases' evidence is unchanged.
"""
import io
import json
import hashlib
from pathlib import Path
import sys

import pymupdf
from PIL import Image

from update_sepsis_source import ROOT, DOC, SHA256, CARDS
from sync_pdf_evidence import locate, normalized, tokens

def load(p): return json.loads(p.read_text(encoding='utf8'))

def validate(baseline=None):
    pdf=ROOT/'assets/pdfs'/DOC
    assert hashlib.sha256(pdf.read_bytes()).hexdigest()==SHA256
    source=ROOT.parent/DOC
    assert source.read_bytes()==pdf.read_bytes()
    doc=pymupdf.open(pdf)
    assert len(doc)==1
    page=doc[0]
    regions=load(ROOT/'assets/regions/regions.json')
    index=load(ROOT/'assets/stw_index/stw_index.json')
    entries={r['id']:r for r in regions if r['id'].startswith('sepsis_')}
    chunks={r['chunk_id']:r for r in index if r['chunk_id'].startswith('sepsis_')}
    assert len(entries)==len(CARDS)==len(chunks)
    words=[(t,pymupdf.Rect(w[:4]),round(w[1],1)) for w in page.get_text('words') for t in tokens(w[4])]
    segment_count=0
    for id,r in entries.items():
        rect=pymupdf.Rect(CARDS[id.removeprefix('sepsis_')][0])
        lines=[s.strip().lstrip('•·').strip() for s in page.get_text(clip=rect).splitlines()]
        assert r['text']=='\n'.join(s for s in lines if s),id
        assert r['source_sha256']==SHA256 and r['source_revision']==DOC
        for key,value in r.items(): assert chunks[id][key]==value,(id,key)
        assert chunks[id]['bounding_boxes']==[dict(x=r['x'],y=r['y'],width=r['w'],height=r['h'])]
        local=[w for w in words if rect.contains((w[1].tl+w[1].br)/2)]
        for seg in r['segments']:
            boxes,coverage=locate(seg['text'],local,rect)
            assert coverage==1,(id,seg['text'])
            assert seg['bounding_boxes']==[normalized(b,page) for b in boxes],id
            assert all((rect+(-0.1,-0.1,0.1,0.1)).contains(b) for b in boxes),id
            segment_count+=1
        pix=page.get_pixmap(matrix=pymupdf.Matrix(2,2),clip=rect)
        result=io.BytesIO()
        Image.frombytes('RGB',(pix.width,pix.height),pix.samples).save(result,format='WEBP',quality=90)
        assert result.getvalue()==(ROOT/r['crop_image']).read_bytes(),id
    pix=page.get_pixmap(matrix=pymupdf.Matrix(1600/page.rect.width,1600/page.rect.width))
    result=io.BytesIO()
    Image.frombytes('RGB',(pix.width,pix.height),pix.samples).save(result,format='WEBP',quality=90)
    assert result.getvalue()==(ROOT/'assets/pages'/DOC/'1.webp').read_bytes()
    if baseline:
        for filename,current in [('regions.json',regions),('stw_index.json',index)]:
            old=load(baseline/filename)
            filtered=lambda rows:[r for r in rows if not (r.get('id') or r.get('chunk_id','')).startswith('sepsis_')]
            assert filtered(old)==filtered(current),'Other disease evidence changed: '+filename
        old=load(baseline/'stw_map.json');new=load(ROOT/'assets/knowledge_graph/stw_map.json')
        assert old['links']==new['links'] and old['contexts']==new['contexts']
        assert old['headings']=={k:v for k,v in new['headings'].items() if not k.startswith('sepsis_')}
        previous=load(baseline/'baseline.json')
        for name,digest in previous.items():
            if name.startswith(('assets/pdfs/','assets/regions/crops/','assets/pages/')) and name!='assets/pages/pages.json':
                assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
            if name.startswith(('lib/features/rd/','lib/features/rop/','lib/features/ancs/','lib/features/hypoglycemia/','lib/features/triage/','lib/features/kmc/')):
                assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
        print('Other disease workflows, PDFs, crops, pages and source catalogs unchanged')
    print(f'PASS: pinned supplied PDF; {len(entries)} cards; {segment_count} segments; exact source geometry; matching fallback index; crops and full page')

if __name__=='__main__': validate(Path(sys.argv[1]) if len(sys.argv)>1 else None)
