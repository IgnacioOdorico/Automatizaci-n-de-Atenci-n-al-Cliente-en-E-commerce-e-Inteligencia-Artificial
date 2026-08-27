# -*- coding: utf-8 -*-
"""Figuras 1 y 2 estaban estiradas: el marco del documento no respeta la
proporción natural de la imagen. Verificado que NO hay <a:srcRect> (no es
recorte) y que sí hay <a:stretch>, o sea que Word las deforma al dibujarlas.

Se conserva el ancho (que es el que ajusta a la caja de texto) y se recalcula
el alto a partir de la proporción real del PNG.
"""
import zipfile
import shutil
import re
import io
import os
from PIL import Image

DOCX = 'docs/TESIS_FINAL_UTN_v6.docx'
TMP = DOCX + '.tmp2'
shutil.copy(DOCX, DOCX + '.bak-figs')

zin = zipfile.ZipFile(DOCX, 'r')
rels = zin.read('word/_rels/document.xml.rels').decode('utf-8')
doc = zin.read('word/document.xml').decode('utf-8')

# proporción natural de cada imagen
ratio_de_rid = {}
for m in re.finditer(r'Id="(rId\d+)"[^>]*Target="(media/image\d+\.png)"', rels):
    rid, target = m.group(1), m.group(2)
    im = Image.open(io.BytesIO(zin.read('word/' + target)))
    ratio_de_rid[rid] = (im.size[0] / im.size[1], target, im.size)

cambios = []
partes = re.split(r'(<w:drawing>.*?</w:drawing>)', doc, flags=re.S)
for i, parte in enumerate(partes):
    if not parte.startswith('<w:drawing>'):
        continue
    m = re.search(r'r:embed="(rId\d+)"', parte)
    if not m or m.group(1) not in ratio_de_rid:
        continue
    rid = m.group(1)
    ratio, target, size = ratio_de_rid[rid]
    if '<a:srcRect' in parte and re.search(r'<a:srcRect\s+[lrtb]', parte):
        continue                       # hay recorte real: no tocar
    e = re.search(r'<wp:extent cx="(\d+)" cy="(\d+)"', parte)
    if not e:
        continue
    cx, cy = int(e.group(1)), int(e.group(2))
    cy_ok = int(round(cx / ratio))
    if abs((cx / cy) - ratio) < 0.01:
        continue                       # ya está bien
    partes[i] = re.sub(r'cx="%d" cy="%d"' % (cx, cy), 'cx="%d" cy="%d"' % (cx, cy_ok), parte)
    cambios.append((target, size, cy / 360000, cy_ok / 360000, (cx/cy), ratio))

doc_nuevo = ''.join(partes)

zout = zipfile.ZipFile(TMP, 'w', zipfile.ZIP_DEFLATED)
for item in zin.infolist():
    data = zin.read(item.filename)
    if item.filename == 'word/document.xml':
        data = doc_nuevo.encode('utf-8')
    zout.writestr(item, data)
zin.close()
zout.close()
os.replace(TMP, DOCX)

print('Marcos corregidos: %d' % len(cambios))
for target, size, alto_ant, alto_new, r_ant, r_ok in cambios:
    print('  %-14s %-12s alto %.2f cm -> %.2f cm   (ratio %.3f -> %.3f)'
          % (target.split('/')[-1], str(size), alto_ant, alto_new, r_ant, r_ok))
