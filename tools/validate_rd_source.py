#!/usr/bin/env python3
"""Validate the RD PDF, text, geometry, crops and optional preservation snapshot."""
import argparse
import hashlib
import io
import json
from pathlib import Path

import pymupdf
from PIL import Image

from update_rd_source import CARDS, DOC, ROOT, SOURCE_SHA256
from sync_pdf_evidence import tokens

def load(p): return json.loads(p.read_text(encoding='utf8'))

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path)
    parser.add_argument('--baseline',type=Path)
    args=parser.parse_args()
    pdf=ROOT/'assets/pdfs'/DOC
    digest=hashlib.sha256(pdf.read_bytes()).hexdigest()
    assert digest==SOURCE_SHA256, 'Unexpected source revision'
    if args.source: assert pdf.read_bytes()==args.source.read_bytes(), 'Bundled PDF differs from supplied PDF'
    page=pymupdf.open(pdf)[0]
    regions=load(ROOT/'assets/regions/regions.json')
    index=load(ROOT/'assets/stw_index/stw_index.json')
    by_id={c['chunk_id']:c for c in index}
    rd=[r for r in regions if r['id'].startswith('rd_')]
    assert {r['id'] for r in rd}==set(CARDS)
    for r in rd:
        id=r['id']
        assert r['source_sha256']==digest
        assert r['document']==DOC and r['page']==1
        assert r['source_revision']=='Respiratory_Distress_STW_Final 15-10-26.pdf'
        rect=pymupdf.Rect(CARDS[id])
        lines=[l.strip().lstrip('•').strip() for l in page.get_text(clip=rect).splitlines()]
        assert r['text']=='\n'.join(l for l in lines if l and l!='•'),id
        for key,value in r.items(): assert by_id[id][key]==value,(id,key)
        for seg in r['segments']:
            assert seg['bounding_boxes'], (id,seg['text'])
            evidence=[]
            for box in seg['bounding_boxes']:
                actual=pymupdf.Rect(box['x']*page.rect.width,box['y']*page.rect.height,
                    (box['x']+box['width'])*page.rect.width,(box['y']+box['height'])*page.rect.height)
                assert (rect+(-1,-1,1,1)).contains(actual),(id,actual)
                evidence.extend(tokens(page.get_text(clip=actual+(-1,-1,1,1))))
            assert set(tokens(seg['text']))<=set(evidence),(id,seg['text'])
        pix=page.get_pixmap(matrix=pymupdf.Matrix(2,2),clip=rect)
        out=io.BytesIO()
        Image.frombytes('RGB',(pix.width,pix.height),pix.samples).save(out,format='WEBP',quality=90)
        assert (ROOT/r['crop_image']).read_bytes()==out.getvalue(), f'{id}: stale crop'
    assert not (ROOT/'assets/pdfs/Respiratory distress in neonates_New.pdf').exists()
    pages=load(ROOT/'assets/pages/pages.json')
    assert not any(x['document']=='Respiratory distress in neonates_New.pdf' for x in pages)
    p=next(x for x in pages if x['document']==DOC)
    pix=page.get_pixmap(matrix=pymupdf.Matrix(1600/page.rect.width,1600/page.rect.width))
    out=io.BytesIO()
    Image.frombytes('RGB',(pix.width,pix.height),pix.samples).save(out,format='WEBP',quality=90)
    assert (ROOT/p['image_path']).read_bytes()==out.getvalue(),'Stale rendered PDF page'
    if args.baseline:
        base=args.baseline
        for current,name,key in [(regions,'regions.json','id'),(index,'stw_index.json','chunk_id')]:
            before=load(base/name)
            other=lambda entries:[r for r in entries if not r.get('id',r.get(key,'')).startswith('rd_')]
            assert other(current)==other(before),f'{name}: another disease changed'
        graph=load(ROOT/'assets/knowledge_graph/stw_map.json')
        before=load(base/'stw_map.json')
        for key in ['headings','contexts']:
            other=lambda data:{k:v for k,v in data[key].items() if not k.startswith('rd_')}
            assert other(graph)==other(before),f'Non-RD graph {key} changed'
        other=lambda data:[r for r in data['links'] if not r['id'].startswith('rd-')]
        assert other(graph)==other(before),'Another disease graph link changed'
        hashes=load(base/'baseline.json')
        protected=[p for p in hashes if
            p.startswith(tuple(f'lib/features/{d}/' for d in ['ancs','hypoglycemia','rop','triage','kmc'])) or
            p.startswith('assets/regions/crops/') and not Path(p).name.startswith('rd_') or
            p.startswith('assets/pdfs/') and 'respiratory' not in p.lower()]
        for p in protected:
            assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==hashes[p],f'Another disease file changed: {p}'
        print(f'Preservation verified: {len(protected)} other-disease files and all non-RD catalog/graph entries unchanged.')
    print(f'PASS: {len(rd)} RD cards, all text/segment coordinates, fallback index, 2x crops and full-page render. SHA256 {digest}')

if __name__=='__main__': main()
