"""Verify the RD question fixture against the retained, unmodified DOCX source.

Flutter tests compare this fixture with the actual compiled question package.
Only Word's Q/A prefixes and surrounding whitespace are removed.
"""
import hashlib
import json
import re
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/MCQs RD.docx'
NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}


def text(element):
    return ''.join(
        node.text or '' if node.tag.endswith('}t') else
        '\n' if node.tag.endswith('}br') else
        '\t' if node.tag.endswith('}tab') else ''
        for node in element.iter()
    ).strip()


def main():
    with ZipFile(SOURCE) as archive:
        document = ET.fromstring(archive.read('word/document.xml'))
    questions = []
    section = 0
    for paragraph in document.findall('./w:body/w:p', NS):
        value = text(paragraph)
        if value.startswith('Section '):
            section = int(re.search(r'\d+', value)[0])
        elif re.match(r'Q\d+\.', value):
            questions.append({
                'number': int(re.match(r'Q(\d+)', value)[1]),
                'section': section,
                'question': re.sub(r'^Q\d+\.\s*', '', value),
                'options': [],
                'correctAnswerIndex': None,
            })
        elif re.match(r'^[A-D]\)', value):
            item = questions[-1]
            item['options'].append(value[3:].strip())
            if any(run.find('w:rPr/w:b', NS) is not None and text(run)
                   for run in paragraph.findall('w:r', NS)):
                assert item['correctAnswerIndex'] is None, 'Multiple bold answers'
                item['correctAnswerIndex'] = len(item['options']) - 1
        elif value.startswith('Explanation:'):
            questions[-1]['explanation'] = value[len('Explanation:'):].strip()

    assert len(questions) == 20
    assert [q['number'] for q in questions] == list(range(1, 21))
    assert [q['section'] for q in questions] == [1] * 10 + [2] * 10
    assert all(len(q['options']) == 4 and q['correctAnswerIndex'] is not None
               and q['explanation'] for q in questions)
    actual = {
        'source': SOURCE.name,
        'sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'questions': questions,
    }
    expected = json.loads((ROOT / 'test/fixtures/rd_follow_up_source.json').read_text(encoding='utf8'))
    assert actual == expected, 'DOCX source or extracted fixture has changed'
    print('PASS: all 20 questions, options, bold answer keys and explanations match the DOCX')


if __name__ == '__main__':
    main()
