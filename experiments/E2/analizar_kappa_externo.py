# -*- coding: utf-8 -*-
"""
A-03 — Acuerdo entre anotadores (kappa de Cohen)

Compara las etiquetas del segundo anotador (etiquetar_externo.html) contra el
ground truth de la Ronda 1, sobre la misma muestra de 50 mensajes.

Uso:
    python analizar_kappa_externo.py resultados/etiquetas_evaluador_externo.csv

Reporta:
    - Control de validez del etiquetado (tiempos): el mismo chequeo forense que
      invalidó la Ronda 1 (150 mensajes en 50 s = teclas al azar, no etiquetado).
    - Acuerdo observado (Po), esperado por azar (Pe) y kappa de Cohen.
    - Desacuerdos caso por caso: son los casos frontera, y son lo más informativo
      del análisis (van al capítulo, no se esconden).
"""
import csv, sys, os
from collections import Counter, defaultdict

BASE = os.path.dirname(os.path.abspath(__file__))
GT = os.path.join(BASE, "etiquetas_ronda1.csv")          # ground truth (anotador 1)
CORPUS = os.path.join(BASE, "corpus_intents.csv")
CLASES = ["FAQ", "ESTADO_PEDIDO", "RECLAMO", "GENERAL"]


def leer(path, campo="intent"):
    with open(path, encoding="utf-8-sig") as f:
        return {r["id"].strip(): r for r in csv.DictReader(f)}


def titulo(t):
    print("\n" + "=" * 62)
    print(" " + t)
    print("=" * 62)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    ext_path = sys.argv[1]

    ext = leer(ext_path)
    gt = leer(GT)
    corpus = leer(CORPUS)

    ids = [i for i in ext if i in gt]
    n = len(ids)
    if n == 0:
        print("ERROR: ningún id del archivo coincide con el ground truth.")
        sys.exit(1)

    # ---------- 1. Validez del etiquetado (control forense) ----------
    titulo("1. CONTROL DE VALIDEZ DEL ETIQUETADO")
    tiempos = []
    for i in ids:
        try:
            tiempos.append(float(ext[i].get("segundos", "0").replace(",", ".")))
        except ValueError:
            pass
    if tiempos:
        tiempos_ord = sorted(tiempos)
        mediana = tiempos_ord[len(tiempos_ord) // 2]
        bajo_1s = sum(1 for t in tiempos if t < 1.0)
        total_min = sum(tiempos) / 60
        print(f"  Mensajes etiquetados : {n}")
        print(f"  Tiempo total         : {total_min:.1f} min")
        print(f"  Mediana por mensaje  : {mediana:.1f} s")
        print(f"  Bajo 1 segundo       : {bajo_1s} de {n}")
        if mediana < 1.0 or bajo_1s > n * 0.5:
            print("\n  >> INVALIDO: los tiempos indican que no hubo lectura real.")
            print("     Este fue el patron que invalido la Ronda 1. No usar.")
        else:
            print("\n  >> Los tiempos son compatibles con un etiquetado genuino.")

    # ---------- 2. Distribución de cada anotador ----------
    titulo("2. DISTRIBUCION POR ANOTADOR")
    d_ext = Counter(ext[i]["intent"].strip() for i in ids)
    d_gt = Counter(gt[i]["intent"].strip() for i in ids)
    print(f"  {'clase':16}{'anotador 1':>12}{'anotador 2':>12}")
    for c in CLASES:
        print(f"  {c:16}{d_gt[c]:>12}{d_ext[c]:>12}")

    # ---------- 3. Kappa de Cohen ----------
    titulo("3. ACUERDO ENTRE ANOTADORES (kappa de Cohen)")
    acuerdos = sum(1 for i in ids if ext[i]["intent"].strip() == gt[i]["intent"].strip())
    po = acuerdos / n
    pe = sum((d_gt[c] / n) * (d_ext[c] / n) for c in CLASES)
    kappa = (po - pe) / (1 - pe) if pe < 1 else 1.0

    print(f"  n                      : {n}")
    print(f"  Acuerdos               : {acuerdos} de {n}")
    print(f"  Po (acuerdo observado) : {po:.3f}")
    print(f"  Pe (esperado por azar) : {pe:.3f}")
    print(f"  kappa de Cohen         : {kappa:.3f}")

    if kappa > 0.80:
        interp = "casi perfecto"
    elif kappa > 0.60:
        interp = "sustancial"
    elif kappa > 0.40:
        interp = "moderado"
    elif kappa > 0.20:
        interp = "aceptable/debil"
    else:
        interp = "pobre"
    print(f"\n  >> Acuerdo {interp} (escala de Landis & Koch, 1977).")

    # ---------- 4. Desacuerdos ----------
    titulo("4. DESACUERDOS (casos frontera)")
    desac = [i for i in ids if ext[i]["intent"].strip() != gt[i]["intent"].strip()]
    if not desac:
        print("  Sin desacuerdos.")
    else:
        print(f"  {len(desac)} de {n} casos. Estos son los limites semanticos reales")
        print("  entre categorias: van reportados en el capitulo, no se ocultan.\n")
        pares = defaultdict(int)
        for i in desac:
            a1, a2 = gt[i]["intent"].strip(), ext[i]["intent"].strip()
            pares[(a1, a2)] += 1
            msg = corpus.get(i, {}).get("mensaje", "")[:52]
            print(f"    id {i:>4} | anot.1: {a1:14} | anot.2: {a2:14} | {msg}")
        print("\n  Pares de confusion mas frecuentes:")
        for (a1, a2), c in sorted(pares.items(), key=lambda x: -x[1]):
            print(f"    {a1} <-> {a2}: {c}")

    titulo("PARA EL CAPITULO 3 (protocolo) Y 5 (resultados)")
    print(f"  \"Un segundo anotador etiqueto de forma ciega una muestra de {n}")
    print(f"   mensajes del corpus. El acuerdo entre anotadores fue de Po={po:.3f}")
    print(f"   con un kappa de Cohen de {kappa:.3f} (acuerdo {interp}), calculado")
    print(f"   sobre las cuatro categorias de intencion.\"")
    print()


if __name__ == "__main__":
    main()
