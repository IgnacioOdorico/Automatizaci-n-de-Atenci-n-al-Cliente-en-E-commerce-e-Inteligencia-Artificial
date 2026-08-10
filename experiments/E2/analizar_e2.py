#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
E2 / E3 — Análisis del corpus del chatbot.

Cruza el ground truth humano (etiquetas_ronda1.csv) contra las
clasificaciones que produjo GPT-4o-mini y quedaron en la tabla
interactions, escritas por el workflow.

Produce todo lo que pide el plan (§4.4) y que la tesis v5 no tenía:

  - Accuracy global con IC de Wilson al 95%
  - Matriz de confusión 4x4
  - Precision, recall y F1 por intent
  - Test binomial exacto de una cola contra H0: p = 0,85
  - Kappa intra-anotador (ronda 1 vs ronda 2), si existe la ronda 2
  - TMR por intent con GROUP BY  (esto es E3, cierra A-05)

Solo biblioteca estándar: sin numpy, sin scipy, sin pandas.

Uso:
    python analizar_e2.py
    python analizar_e2.py > resultados/e2_analisis_$(fecha).txt

Referencia: docs/PLAN_REGENERACION_EVIDENCIA.md §4 y §5
"""

import csv
import math
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

AQUI      = Path(__file__).resolve().parent
CORPUS    = AQUI / 'corpus_intents.csv'
RONDA1    = AQUI / 'etiquetas_ronda1.csv'
RONDA2    = AQUI / 'etiquetas_ronda2.csv'

CONTENEDOR = 'tesis_postgres'
BASE       = 'ecommerce_tesis'
USUARIO    = 'n8n_user'

INTENTS = ['FAQ', 'ESTADO_PEDIDO', 'RECLAMO', 'GENERAL']
UMBRAL  = 0.85          # H0 del test binomial (criterio propio del equipo, ver C-06)


# ------------------------------------------------------------------
#  Utilidades de presentación
# ------------------------------------------------------------------

def titulo(t):
    print()
    print('=' * 62)
    print(f' {t}')
    print('=' * 62)


def sub(t):
    print()
    print(f'--- {t} ' + '-' * max(0, 56 - len(t)))


# ------------------------------------------------------------------
#  Estadística (todo a mano, sin dependencias)
# ------------------------------------------------------------------

def wilson(exitos, n, z=1.96):
    """
    Intervalo de confianza de Wilson para una proporción.

    Se usa Wilson y no el intervalo normal porque con proporciones
    cercanas a 1 —que es exactamente el caso acá— el normal se rompe:
    puede dar límites por encima de 1 y su cobertura real cae muy por
    debajo del 95% nominal.
    """
    if n == 0:
        return (0.0, 0.0)
    p = exitos / n
    d = 1 + z * z / n
    centro = (p + z * z / (2 * n)) / d
    margen = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, centro - margen), min(1.0, centro + margen))


def binomial_cola_superior(k, n, p):
    """
    P(X >= k) con X ~ Binomial(n, p). Test exacto de una cola.

    Responde: si el clasificador fuera exactamente del 85%, ¿qué tan
    probable sería observar k aciertos o más por puro azar?
    """
    return sum(math.comb(n, i) * p**i * (1 - p)**(n - i) for i in range(k, n + 1))


def kappa_cohen(a, b):
    """
    Kappa de Cohen entre dos series de etiquetas apareadas.

    Acá se usa como concordancia INTRA-anotador (test-retest): la misma
    persona etiquetando el mismo mensaje en dos momentos distintos. No es
    lo mismo que la concordancia entre dos anotadores independientes, y
    la tesis debe decirlo (§5.2, ver plan §14.4).
    """
    n = len(a)
    if n == 0:
        return None
    po = sum(1 for x, y in zip(a, b) if x == y) / n
    ca, cb = Counter(a), Counter(b)
    pe = sum((ca[k] / n) * (cb[k] / n) for k in set(ca) | set(cb))
    if pe == 1:
        return None
    return (po - pe) / (1 - pe)


def interpretar_kappa(k):
    # Escala de Landis & Koch (1977)
    if k < 0.00: return 'pobre'
    if k < 0.20: return 'leve'
    if k < 0.40: return 'aceptable'
    if k < 0.60: return 'moderada'
    if k < 0.80: return 'sustancial'
    return 'casi perfecta'


# ------------------------------------------------------------------
#  Acceso a datos
# ------------------------------------------------------------------

def psql(sql):
    """Ejecuta SQL en el contenedor y devuelve filas como listas de campos."""
    cmd = ['docker', 'exec', '-i', CONTENEDOR, 'psql', '-U', USUARIO, '-d', BASE,
           '-t', '-A', '-F', '\t', '-v', 'ON_ERROR_STOP=1']
    try:
        r = subprocess.run(cmd, input=sql, capture_output=True, text=True,
                           encoding='utf-8', timeout=60)
    except FileNotFoundError:
        sys.exit('ERROR: no se encontró docker en el PATH.')
    if r.returncode != 0:
        sys.exit(f'ERROR de psql:\n{r.stderr}')
    return [ln.split('\t') for ln in r.stdout.splitlines() if ln.strip()]


def leer_csv(ruta, campos):
    if not ruta.exists():
        return None
    with open(ruta, encoding='utf-8-sig', newline='') as f:
        filas = list(csv.DictReader(f))
    if filas and not all(c in filas[0] for c in campos):
        sys.exit(f'ERROR: {ruta.name} no tiene las columnas {campos}.')
    return filas


# ------------------------------------------------------------------
#  Programa
# ------------------------------------------------------------------

def main():
    corpus = leer_csv(CORPUS, ['id', 'user_id', 'mensaje'])
    if corpus is None:
        sys.exit(f'ERROR: no existe {CORPUS.name}.')

    verdad = leer_csv(RONDA1, ['id', 'intent'])
    if verdad is None:
        sys.exit(f'ERROR: no existe {RONDA1.name}. Etiquetá primero con etiquetar.html.')

    por_id   = {f['id']: f for f in corpus}
    gt       = {f['id']: f['intent'].strip().upper() for f in verdad}
    id_de_usr = {f['user_id']: f['id'] for f in corpus}

    titulo('E2 — CLASIFICACIÓN DE INTENTS')
    print(f'  Corpus:       {len(corpus)} mensajes')
    print(f'  Ground truth: {len(gt)} etiquetas humanas')

    desconocidos = {v for v in gt.values() if v not in INTENTS}
    if desconocidos:
        sys.exit(f'ERROR: el ground truth tiene etiquetas fuera del vocabulario: {desconocidos}')

    # --- Control de validez del etiquetado ---
    if 'segundos' in verdad[0]:
        segs = sorted(float(f['segundos']) for f in verdad)
        mediana = segs[len(segs) // 2]
        sub('Control de validez del etiquetado')
        print(f'  Mediana: {mediana:.2f} s por mensaje')
        if mediana < 3:
            print('  *** ATENCIÓN: por debajo de ~3 s es dudoso que se hayan leído')
            print('      los mensajes. Un ground truth al azar hace que el accuracy')
            print('      no mida nada. Revisalo antes de publicar cualquier número.')
        else:
            print('  OK — tiempos compatibles con un etiquetado leído.')

    # --- Predicciones del modelo, desde la BD ---
    ids_sql = ','.join(f"'{f['user_id']}'" for f in corpus)
    filas = psql(f"""
SELECT user_id, intent,
       EXTRACT(EPOCH FROM (responded_at - received_at))
FROM interactions
WHERE user_id IN ({ids_sql})
ORDER BY id;
""")
    pred, tmr = {}, {}
    for f in filas:
        if len(f) < 2:
            continue
        mid = id_de_usr.get(f[0].strip())
        if mid is None:
            continue
        pred[mid] = f[1].strip().upper()
        if len(f) > 2 and f[2].strip():
            tmr[mid] = float(f[2])

    # --- Conciliación (B-6.6) ---
    sub('Conciliación (B-6.6)')
    faltan = [i for i in gt if i not in pred]
    print(f'  Enviados:            {len(gt)}')
    print(f'  Con fila escrita:    {len(pred)}')
    print(f'  SIN fila:            {len(faltan)}')
    if faltan:
        print()
        print('  *** Estos mensajes no dejaron fila. Causa más probable: el modelo')
        print('      devolvió una etiqueta fuera del vocabulario y el INSERT violó')
        print('      el CHECK. Son los peores casos del modelo: si se los excluye,')
        print('      el accuracy sube solo. Hay que explicar cada uno con el log de')
        print('      ejecuciones de n8n y contarlos como FALLO, no ignorarlos.')
        for i in faltan[:15]:
            print(f'      #{i:>3}  "{por_id[i]["mensaje"][:52]}"')
        if len(faltan) > 15:
            print(f'      ... y {len(faltan) - 15} más (ver e2_faltantes_*.csv)')

    if not pred:
        sys.exit('\nNo hay ninguna clasificación en la BD. ¿Corriste run_flujo2_corpus.ps1?')

    # --- Accuracy ---
    # Denominador = ENVIADOS, no registrados. Un mensaje sin fila es un fallo
    # del sistema, no un caso inexistente (B-6.6).
    n_env = len(gt)
    aciertos = sum(1 for i, v in gt.items() if pred.get(i) == v)
    acc = aciertos / n_env
    lo, hi = wilson(aciertos, n_env)

    titulo('ACCURACY')
    print(f'  Aciertos:  {aciertos} / {n_env}')
    print(f'  Accuracy:  {acc*100:.1f}%')
    print(f'  IC 95% Wilson:  [{lo*100:.1f}% ; {hi*100:.1f}%]')
    print()
    print(f'  (sobre los {len(pred)} registrados seria {sum(1 for i,v in gt.items() if i in pred and pred[i]==v)/len(pred)*100:.1f}%,')
    print('   pero ese numero NO es el que se publica: infla el resultado)')

    # --- Test binomial ---
    p_val = binomial_cola_superior(aciertos, n_env, UMBRAL)
    sub(f'Test binomial exacto contra H0: p = {UMBRAL:.2f}')
    print(f'  H0: la tasa real de acierto es {UMBRAL*100:.0f}%')
    print(f'  H1: es mayor que {UMBRAL*100:.0f}%  (una cola)')
    print(f'  p-valor = {p_val:.4f}')
    if p_val < 0.05:
        print(f'  => Se RECHAZA H0 al 5%. El accuracy supera el umbral de forma significativa.')
    else:
        print(f'  => NO se rechaza H0 al 5%. Con esta muestra no se puede afirmar')
        print(f'     que se supere el {UMBRAL*100:.0f}%. Hay que decirlo así en la tesis.')

    # --- Matriz de confusión ---
    titulo('MATRIZ DE CONFUSIÓN')
    print('  Filas = etiqueta humana (verdad)   Columnas = predicción del modelo')
    print("  '(sin fila)' = el INSERT no se escribió (B-6.6)")
    print()
    mat = defaultdict(Counter)
    for i, v in gt.items():
        mat[v][pred.get(i, '(sin fila)')] += 1

    cols = INTENTS + (['(sin fila)'] if faltan else [])
    anchos = [max(12, len(c) + 2) for c in cols]
    print('  ' + ' ' * 15 + ''.join(c.rjust(a) for c, a in zip(cols, anchos)) + '     total')
    for v in INTENTS:
        fila = ''.join(str(mat[v][c]).rjust(a) for c, a in zip(cols, anchos))
        print(f'  {v:<15}{fila}{sum(mat[v].values()):>10}')

    # --- Precision / recall / F1 ---
    titulo('PRECISION, RECALL Y F1 POR INTENT')
    print('  El accuracy global esconde qué intent es el más débil.')
    print()
    print(f'  {"intent":<16}{"n":>5}{"precision":>12}{"recall":>10}{"F1":>8}')
    print('  ' + '-' * 51)
    f1s = []
    for c in INTENTS:
        tp = sum(1 for i, v in gt.items() if v == c and pred.get(i) == c)
        fp = sum(1 for i, v in gt.items() if v != c and pred.get(i) == c)
        fn = sum(1 for i, v in gt.items() if v == c and pred.get(i) != c)
        soporte = sum(1 for v in gt.values() if v == c)
        prec = tp / (tp + fp) if tp + fp else 0.0
        rec  = tp / (tp + fn) if tp + fn else 0.0
        f1   = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
        f1s.append(f1)
        print(f'  {c:<16}{soporte:>5}{prec:>11.3f}{rec:>10.3f}{f1:>8.3f}')
    print('  ' + '-' * 51)
    print(f'  {"F1 macro":<16}{"":>5}{"":>11}{"":>10}{sum(f1s)/len(f1s):>8.3f}')

    # --- E3: TMR por intent ---
    titulo('E3 — TMR POR INTENT (cierra A-05)')
    print('  El error original fue copiar el promedio global en las 4 filas.')
    print('  Esto es un GROUP BY de verdad sobre las mismas mediciones.')
    print()
    print('  TMR = responded_at - received_at. Va desde la normalización del')
    print('  mensaje dentro de n8n hasta después de despachar la respuesta.')
    print('  NO incluye la latencia del cliente al webhook ni la entrega final')
    print('  en el canal. Esa definición va escrita en §5.2.1 (B-6.3).')
    print()
    print(f'  {"intent":<16}{"n":>5}{"media":>10}{"mediana":>10}{"min":>8}{"max":>8}')
    print('  ' + '-' * 57)
    por_intent = defaultdict(list)
    for i, s in tmr.items():
        por_intent[pred[i]].append(s)
    for c in INTENTS:
        v = sorted(por_intent.get(c, []))
        if not v:
            print(f'  {c:<16}{0:>5}{"—":>10}{"—":>10}{"—":>8}{"—":>8}')
            continue
        media = sum(v) / len(v)
        med = v[len(v)//2] if len(v) % 2 else (v[len(v)//2 - 1] + v[len(v)//2]) / 2
        print(f'  {c:<16}{len(v):>5}{media:>10.3f}{med:>10.3f}{v[0]:>8.3f}{v[-1]:>8.3f}')
    todos = sorted(tmr.values())
    if todos:
        print('  ' + '-' * 57)
        med_g = todos[len(todos)//2] if len(todos) % 2 else (todos[len(todos)//2-1]+todos[len(todos)//2])/2
        print(f'  {"** GLOBAL **":<16}{len(todos):>5}{sum(todos)/len(todos):>10.3f}{med_g:>10.3f}{todos[0]:>8.3f}{todos[-1]:>8.3f}')

    # --- Kappa intra-anotador ---
    titulo('CONCORDANCIA INTRA-ANOTADOR (test-retest)')
    r2 = leer_csv(RONDA2, ['id', 'intent'])
    if r2 is None:
        print(f'  No existe {RONDA2.name} todavía.')
        print()
        print('  Con un solo anotador no se puede calcular el kappa de Cohen')
        print('  inter-anotador que pedía el plan original. Se reemplaza por')
        print('  test-retest: re-etiquetar 50 mensajes al azar, idealmente al')
        print('  día siguiente, con la ronda 2 de etiquetar.html.')
    else:
        g2 = {f['id']: f['intent'].strip().upper() for f in r2}
        comunes = sorted(set(gt) & set(g2), key=int)
        if not comunes:
            print('  La ronda 2 no comparte ningún id con la ronda 1.')
        else:
            a = [gt[i] for i in comunes]
            b = [g2[i] for i in comunes]
            k = kappa_cohen(a, b)
            coincide = sum(1 for x, y in zip(a, b) if x == y)
            print(f'  Mensajes re-etiquetados: {len(comunes)}')
            print(f'  Coincidencias:           {coincide} / {len(comunes)}  ({coincide/len(comunes)*100:.1f}%)')
            if k is None:
                print('  Kappa: no calculable (una sola categoría en juego)')
            else:
                print(f'  Kappa intra-anotador:    {k:.3f}  ({interpretar_kappa(k)})')
                if k < 0.70:
                    print()
                    print('  *** Por debajo de 0,70 el esquema de intents es ambiguo.')
                    print('      Eso también es un resultado reportable: hay que refinar')
                    print('      las definiciones y decirlo, no esconderlo.')
            desac = [i for i in comunes if gt[i] != g2[i]]
            if desac:
                print()
                print('  Desacuerdos con vos mismo (los casos genuinamente ambiguos):')
                for i in desac[:12]:
                    print(f'    #{i:>3}  {gt[i]:<14} -> {g2[i]:<14} "{por_id[i]["mensaje"][:40]}"')

    # --- Recordatorio de alcance ---
    titulo('LIMITACIONES A DECLARAR EN §5.2')
    print('  1. Los mensajes entran TODOS por WhatsApp. Esto mide clasificación')
    print('     de intents, NO omnicanalidad. El campo canal está hardcodeado')
    print("     a 'whatsapp' en Normalizar Mensaje: no se detecta (C-01).")
    print('  2. Etiquetado por UN ÚNICO anotador. Se reporta concordancia')
    print('     intra-anotador, no kappa de Cohen inter-anotador.')
    print('  3. El corpus fue redactado por un asistente de IA a partir de los')
    print('     mensajes del seed. El ground truth es humano, pero la dificultad')
    print('     del corpus puede estar sesgada por quién lo redactó.')
    print(f'  4. El umbral del {UMBRAL*100:.0f}% es criterio propio del equipo. La cita')
    print('     "Ram & Yih (2021)" que lo fundaba en la v5 no existe (C-06).')
    print()


if __name__ == '__main__':
    main()
