"""Verify the pinned source, semantic excerpts, geometry, images and isolation.

Usage: python tools/validate_feeding_source.py [--baseline build/feeding-module-baseline]
The baseline option proves that all pre-existing evidence entries are unchanged.
"""
import argparse
import hashlib
import json
from pathlib import Path

import pymupdf
from PIL import Image, ImageChops
from update_feeding_source import ROOT, DOC, SHA256, CARDS, build_cards


def load(path):
    return json.loads(path.read_text(encoding='utf8'))


def validate(baseline=None):
    pdf=ROOT/'assets/pdfs'/DOC
    assert hashlib.sha256(pdf.read_bytes()).hexdigest()==SHA256
    if (ROOT.parent/DOC).exists():
        assert pdf.read_bytes()==(ROOT.parent/DOC).read_bytes()
    doc=pymupdf.open(pdf)
    assert len(doc)==1
    page=doc[0]
    expected=build_cards(page)  # Each segment must have 100% local source coverage.
    regions=load(ROOT/'assets/regions/regions.json')
    actual=[r for r in regions if r['id'].startswith('feeding_')]
    assert actual==expected, 'Source text or highlight geometry drift'
    assert len({r['id'] for r in regions})==len(regions)
    index=load(ROOT/'assets/stw_index/stw_index.json')
    for r in actual:
        entry=next(x for x in index if x.get('id',x.get('chunk_id'))==r['id'])
        for key,value in r.items(): assert entry[key]==value,(r['id'],key)
        rect=pymupdf.Rect(CARDS[r['id'].removeprefix('feeding_')][0])
        pix=page.get_pixmap(matrix=pymupdf.Matrix(2,2),clip=rect)
        image=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
        import io
        encoded=io.BytesIO();image.save(encoded,format='WEBP',quality=90)
        assert encoded.getvalue()==(ROOT/r['crop_image']).read_bytes(),r['id']
    pages=load(ROOT/'assets/pages/pages.json')
    entry=next(p for p in pages if p['document']==DOC)
    assert entry['image_path']==f'assets/pages/{DOC}/1.webp'
    pix=page.get_pixmap(matrix=pymupdf.Matrix(1600/page.rect.width,1600/page.rect.width))
    image=Image.open(ROOT/entry['image_path'])
    assert image.size==(pix.width,pix.height)
    import io
    encoded=io.BytesIO()
    Image.frombytes('RGB',(pix.width,pix.height),pix.samples).save(encoded,format='WEBP',quality=92)
    assert encoded.getvalue()==(ROOT/entry['image_path']).read_bytes(),'Full-page render drift'
    graph=load(ROOT/'assets/knowledge_graph/stw_map.json')
    for r in actual: assert graph['headings'][r['id']]==r['title']
    if baseline:
        baseline=Path(baseline)
        for file in ['assets/regions/regions.json','assets/stw_index/stw_index.json']:
            now=[r for r in load(ROOT/file) if not r.get('id',r.get('chunk_id','')).startswith('feeding_')]
            assert now==load(baseline/file),f'Other disease evidence changed: {file}'
        old=load(baseline/'assets/knowledge_graph/stw_map.json')
        for key,value in old.items():
            if key=='headings':
                assert {k:v for k,v in graph[key].items() if not k.startswith('feeding_')}==value
            else: assert graph[key]==value,f'Existing graph {key} changed'
        manifest={file.replace('\\','/'):sha for file,sha in load(baseline/'hashes.json').items()}
        # Existing PDFs/crops/renders and clinical implementations are immutable.
        for file,sha in manifest.items():
            if file.startswith(('assets/pdfs/','assets/regions/crops/','assets/pages/')) and file!='assets/pages/pages.json':
                assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==sha,file
            if file.startswith(tuple(f'lib/features/{m}/domain/' for m in ['rd','rop','ancs','hypoglycemia','sepsis','triage','kmc'])):
                assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==sha,file
    print(f'PASS: {len(actual)} source cards; {sum(len(r["segments"]) for r in actual)} complete source segments; exact geometry/crops/fallback/graph; preserved existing evidence and clinical modules')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline')
    validate(parser.parse_args().baseline)
