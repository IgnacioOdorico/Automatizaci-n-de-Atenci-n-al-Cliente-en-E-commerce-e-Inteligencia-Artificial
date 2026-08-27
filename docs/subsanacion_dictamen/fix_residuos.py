# -*- coding: utf-8 -*-
"""Dos residuos que la verificación encontró:
   1) §3.5.2 conservaba el IC de Wilson viejo [88,2; 96,3]
   2) El DDL del Anexo A rotula el Flujo 2 como OMNICANAL
"""
import sys
sys.path.insert(0, '.')
from docxkit import *
from docx import Document

RUTA = 'docs/TESIS_FINAL_UTN_v6.docx'
d = Document(RUTA)

n1 = replace_everywhere(d,
    'el intervalo de confianza de Wilson al 95% resulta [88,2%; 96,3%], es decir un margen de '
    'aproximadamente ±4 puntos',
    'el intervalo de confianza de Wilson al 95 % resulta [87,3 %; 95,9 %], es decir un margen de '
    'aproximadamente ±4 puntos')
print('IC de Wilson en §3.5.2: %d' % n1)

n2 = replace_everywhere(d, 'FLUJO 2 — CHATBOT OMNICANAL CON IA', 'FLUJO 2 — CHATBOT MULTICANAL CON IA')
print('Encabezado del DDL: %d' % n2)

d.save(RUTA)

d2 = Document(RUTA)
buscar(d2, r'88,2|96,3 ?%', 'IC viejo (debe ser 0)')
buscar(d2, r'CHATBOT OMNICANAL', 'DDL omnicanal (debe ser 0)')
buscar(d2, r'87,3', 'IC correcto')
