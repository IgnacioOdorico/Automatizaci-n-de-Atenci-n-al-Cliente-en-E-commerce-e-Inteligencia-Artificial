#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
E4 — Baseline de atención manual. Análisis de los tiempos cronometrados.

Uso:
    python experiments/E4/analizar_e4.py experiments/E4/resultados/e4_tiempos_<sello>.csv

Produce:
  - Estadísticos por fase (T1 lectura, T2 actualización, T3 redacción) y del total
  - IC 95% por t de Student (n chico: la normal no corresponde)
  - Desglose por rama (con stock / sin stock)
  - Control del efecto de aprendizaje
  - El factor de mejora contra E1, CON las reservas que hay que declarar

Ver experiments/E4/README.md y docs/PLAN_REGENERACION_EVIDENCIA.md §6
"""

import csv
import sys
import math
import statistics as st

# ------------------------------------------------------------------
#  Constantes del experimento
# ------------------------------------------------------------------
E1_E2E_MEDIA = 0.063   # s — E1.a, n=50, §14.2 del plan
E1_E2E_N     = 50
UMBRAL_H1    = 30.0    # s — el umbral que la propia H1 se fija

# t de Student, dos colas, 95%. Con n≈10 la aproximación normal subestima el IC.
T_975 = {
    1:12.706, 2:4.303, 3:3.182, 4:2.776, 5:2.571, 6:2.447, 7:2.365,
    8:2.306, 9:2.262, 10:2.228, 11:2.201, 12:2.179, 13:2.160, 14:2.145,
    15:2.131, 16:2.120, 17:2.110, 18:2.101, 19:2.093, 20:2.086, 21:2.080,
    22:2.074, 23:2.069, 24:2.064, 25:2.060, 26:2.056, 27:2.052, 28:2.048,
    29:2.045, 30:2.042,
}


def t_critico(df):
    if df <= 0:
        return float('nan')
    if df in T_975:
        return T_975[df]
    return 1.960  # df > 30: la normal ya es buena aproximación


def titulo(t):
    print()
    print('=' * 66)
    print(' ' + t)
    print('=' * 66)


def sub(t):
    print()
    print('--- ' + t + ' ' + '-' * max(0, 60 - len(t)))


def co(x, dec=2):
    """Número con coma decimal, como se escribe en la tesis."""
    return ('%.*f' % (dec, x)).replace('.', ',')


def mmss(s):
    """Segundos a 'M min SS s', que es como se lee un baseline manual."""
    m, r = divmod(s, 60)
    txt = '%d min %04.1f s' % (int(m), r) if m else '%.1f s' % r
    return txt.replace('.', ',')


def resumir(nombre, vals, unidad='s'):
    """Fila de estadísticos para una serie."""
    if not vals:
        print('  %-16s (sin datos)' % nombre)
        return None
    n = len(vals)
    v = sorted(vals)
    media = st.mean(v)
    sd = st.stdev(v) if n > 1 else 0.0
    p95 = v[min(n - 1, int(round(0.95 * (n - 1))))]
    print('  %-16s n=%2d  media=%8.2f  mediana=%8.2f  sd=%7.2f  min=%7.2f  max=%8.2f  p95=%8.2f'
          % (nombre, n, media, st.median(v), sd, v[0], v[-1], p95))
    return {'n': n, 'media': media, 'mediana': st.median(v), 'sd': sd,
            'min': v[0], 'max': v[-1], 'p95': p95}


def ic95(vals):
    """IC 95% de la media por t de Student."""
    n = len(vals)
    if n < 2:
        return None
    media = st.mean(vals)
    ee = st.stdev(vals) / math.sqrt(n)
    h = t_critico(n - 1) * ee
    return (media - h, media + h, ee, t_critico(n - 1))


def pearson(xs, ys):
    n = len(xs)
    if n < 3:
        return float('nan')
    mx, my = st.mean(xs), st.mean(ys)
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    dx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    dy = math.sqrt(sum((y - my) ** 2 for y in ys))
    return num / (dx * dy) if dx and dy else float('nan')


# ------------------------------------------------------------------
def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    ruta = sys.argv[1]
    with open(ruta, encoding='utf-8-sig', newline='') as fh:
        filas = list(csv.DictReader(fh))

    def num(f, k):
        return float(f[k]) if f.get(k) else None

    for f in filas:
        f['_fam'] = f['familiarizacion'] == '1'
        f['_des'] = f['descartada'] == '1'
        f['_t1'] = num(f, 't1_seg')
        f['_t2'] = num(f, 't2_seg')
        f['_t3'] = num(f, 't3_seg')
        f['_tot'] = num(f, 'total_seg')

    validas = [f for f in filas if not f['_des'] and not f['_fam'] and f['_tot'] is not None]
    familia = [f for f in filas if not f['_des'] and f['_fam'] and f['_tot'] is not None]
    descart = [f for f in filas if f['_des']]

    titulo('E4 — BASELINE DE ATENCIÓN MANUAL')
    print('  Archivo: %s' % ruta)
    print('  Órdenes cronometradas: %d' % len(filas))
    print('    válidas (resultado primario): %d' % len(validas))
    print('    de familiarización (aparte):  %d' % len(familia))
    print('    descartadas:                  %d' % len(descart))

    if not validas:
        print('\n  ERROR: no hay órdenes válidas. Nada para analizar.')
        sys.exit(1)

    # ------------------------------------------------------------------
    sub('Integridad')
    ok = True
    for f in filas:
        if f['_des']:
            continue
        partes = [f['_t1'], f['_t2'], f['_t3']]
        if any(p is None for p in partes):
            print('  [!] %s: falta alguna fase' % f['orden']); ok = False
            continue
        if abs(sum(partes) - f['_tot']) > 0.01:
            print('  [!] %s: el total no es T1+T2+T3' % f['orden']); ok = False
        if not f['rama']:
            print('  [!] %s: sin rama registrada' % f['orden']); ok = False
    if len(set(f['orden'] for f in filas)) != len(filas):
        print('  [!] hay órdenes repetidas'); ok = False
    print('  %s' % ('OK: todas las filas consistentes.' if ok else 'REVISAR los avisos de arriba.'))

    # ------------------------------------------------------------------
    titulo('RESULTADO PRIMARIO — %d órdenes válidas' % len(validas))

    sub('Por fase (segundos)')
    resumir('T1 lectura', [f['_t1'] for f in validas])
    resumir('T2 actualiz.', [f['_t2'] for f in validas])
    resumir('T3 redacción', [f['_t3'] for f in validas])
    print()
    tot = resumir('TOTAL', [f['_tot'] for f in validas])

    vals = [f['_tot'] for f in validas]
    lo, hi, ee, tc = ic95(vals)
    sub('Tiempo total por orden')
    print('  Media:      %s   (%.2f s)' % (mmss(tot['media']), tot['media']))
    print('  Mediana:    %s   (%.2f s)' % (mmss(tot['mediana']), tot['mediana']))
    print('  IC 95%%:     [%.2f ; %.2f] s   (t de Student, df=%d, t=%.3f, EE=%.2f)'
          % (lo, hi, len(vals) - 1, tc, ee))
    print('              [%s ; %s]' % (mmss(lo), mmss(hi)))

    sub('Reparto del esfuerzo manual')
    for et, k in (('T1 lectura y verificación', '_t1'),
                  ('T2 actualización en la base', '_t2'),
                  ('T3 redacción del correo', '_t3')):
        m = st.mean([f[k] for f in validas])
        print('  %-30s %6.2f s   %5.1f%%' % (et, m, 100 * m / tot['media']))

    # ------------------------------------------------------------------
    sub('Por rama')
    for rama, et in (('con_stock', 'CON stock (confirmar)'), ('sin_stock', 'SIN stock (avisar)')):
        sel = [f['_tot'] for f in validas if f['rama'] == rama]
        resumir(et, sel)

    # ------------------------------------------------------------------
    titulo('CONTROLES METODOLÓGICOS')

    sub('Efecto de aprendizaje')
    if familia:
        mf = st.mean([f['_tot'] for f in familia])
        print('  Familiarización (n=%d): media %.2f s  (%s)' % (len(familia), mf, mmss(mf)))
        print('  Válidas         (n=%d): media %.2f s  (%s)' % (len(validas), tot['media'], mmss(tot['media'])))
        d = 100 * (mf - tot['media']) / tot['media']
        print('  Las de familiarización fueron un %.1f%% %s.' % (abs(d), 'más lentas' if d > 0 else 'más rápidas'))
        print('  Se reportan aparte, NO se descartan (mismo criterio que el cold start de E1, §14.2).')
    else:
        print('  (sin órdenes de familiarización en el archivo)')

    xs = [int(f['n']) for f in validas]
    r = pearson(xs, vals)
    print()
    print('  Correlación orden-de-ejecución vs tiempo: r = %+.3f' % r)
    if abs(r) < 0.3:
        print('  |r| < 0,3 -> dentro de las válidas ya no hay aprendizaje apreciable.')
        print('  Es el control que justifica promediarlas juntas.')
    else:
        print('  |r| >= 0,3 -> el aprendizaje SIGUE actuando dentro de las válidas.')
        print('  Declararlo: la media subestima el tiempo de un operador no entrenado.')

    cv = tot['sd'] / tot['media'] if tot['media'] else 0
    print()
    print('  Coeficiente de variación: %.1f%%' % (100 * cv))
    print('  %s' % ('Dispersión baja: el procedimiento fue estable.' if cv < 0.25
                    else 'Dispersión alta: declarar que el baseline es variable, no un valor puntual.'))

    # ------------------------------------------------------------------
    titulo('CONTRASTE CON EL PIPELINE AUTOMATIZADO')

    sub('1) La afirmación falsable de H1: end-to-end < 30 s')
    print('  E2E automatizado medido (E1.a, n=%d): %.3f s' % (E1_E2E_N, E1_E2E_MEDIA))
    print('  Umbral que fija H1:                   %.1f s' % UMBRAL_H1)
    print('  Margen: %.0fx por debajo del umbral.' % (UMBRAL_H1 / E1_E2E_MEDIA))
    print('  >> H1 se cumple, y esto NO depende del baseline manual.')
    print('     Reportar esto PRIMERO: es la contrastación de la hipótesis.')

    sub('2) Factor contra el baseline manual medido')
    factor = tot['media'] / E1_E2E_MEDIA
    f_lo, f_hi = lo / E1_E2E_MEDIA, hi / E1_E2E_MEDIA
    print('  Baseline manual (media):  %.2f s  (%s)' % (tot['media'], mmss(tot['media'])))
    print('  Pipeline automatizado:    %.3f s' % E1_E2E_MEDIA)
    print('  Factor:                   %.0fx      (IC 95%%: %.0fx a %.0fx)' % (factor, f_lo, f_hi))
    print('  El E2E automatizado es el %.4f%% del tiempo manual.' % (100 * E1_E2E_MEDIA / tot['media']))
    print()
    print('  !! NO usar este factor como titular. Va con la reserva, en la misma oración:')
    print('     el numerador (%.3f s) es de un pipeline LOCAL — Mailpit en vez de SMTP real,' % E1_E2E_MEDIA)
    print('     sin APIs externas, sin red. Es una COTA SUPERIOR del factor real, no el factor.')
    print('     La tesis ya fue observada por declarar 190x cuando correspondía 31,6x (C-08).')

    sub('3) Contraste con el rango "5 a 30 minutos" que declara el Capítulo 1')
    r_lo, r_hi = 5 * 60.0, 30 * 60.0
    print('  Rango declarado sin fuente (C-09): %s a %s' % (mmss(r_lo), mmss(r_hi)))
    print('  Baseline medido:                   %s' % mmss(tot['media']))
    if tot['media'] < r_lo:
        print()
        print('  >> EL RANGO DECLARADO ESTABA SOBREESTIMADO, no subestimado.')
        print('     Lo medido es %sx MENOR que el piso del rango que la tesis usó' % co(r_lo / tot['media'], 1))
        print('     como denominador de todas sus afirmaciones de impacto.')
        print()
        print('     Esto es un hallazgo propio y hay que declararlo, no esconderlo: la')
        print('     medición CORRIGE A LA BAJA el resultado más vistoso del trabajo.')
        print('     Un equipo que mide y publica un número que lo perjudica es un equipo')
        print('     creíble. Es el argumento más fuerte que E4 puede aportar a la defensa.')
    elif tot['media'] > r_hi:
        print()
        print('  >> Lo medido supera el techo del rango declarado. Verificar el')
        print('     procedimiento antes de reportar: puede haber tiempo muerto adentro.')
    else:
        print()
        print('  >> Lo medido cae DENTRO del rango declarado. El rango resulta ser')
        print('     plausible, pero seguía sin estar medido ni citado: se reemplaza')
        print('     igual por el valor propio, que ahora sí tiene respaldo.')

    sub('4) Latencia de detección — SUPUESTO declarado, nunca sumado a lo medido')
    print('  El baseline mide sólo procesamiento (decisión D-E4-2). Si además se supone que')
    print('  un operador revisa la bandeja cada X minutos, la espera esperada es X/2:')
    print()
    print('  %-14s %-16s %-18s %s' % ('revisa cada', 'espera media', 'total con espera', 'factor'))
    for x in (5, 15, 30, 60):
        esp = x * 60 / 2
        t = tot['media'] + esp
        print('  %-14s %-16s %-18s %.0fx' % ('%d min' % x, mmss(esp), mmss(t), t / E1_E2E_MEDIA))
    print()
    print('  Estas filas son ESCENARIOS, no mediciones. Van rotuladas como tales o no van.')

    # ------------------------------------------------------------------
    titulo('PARA PEGAR EN §5.4')
    print()
    print('  El tiempo de procesamiento manual se midió sobre %d órdenes procesadas por un' % len(validas))
    print('  operador de este equipo contra la misma base de datos y el mismo catálogo que')
    print('  utiliza el pipeline (leer la orden, verificar stock, actualizar el estado y')
    print('  redactar la notificación a partir de una plantilla fija). La media resultante')
    print('  fue de %s por orden (IC 95%%: %s a %s; mediana %s).'
          % (mmss(tot['media']), mmss(lo), mmss(hi), mmss(tot['mediana'])))
    print('  Desglose: lectura y verificación %s, actualización %s, redacción %s.'
          % (co(st.mean([f['_t1'] for f in validas]), 1) + ' s',
             co(st.mean([f['_t2'] for f in validas]), 1) + ' s',
             co(st.mean([f['_t3'] for f in validas]), 1) + ' s'))
    print()
    print('  Este valor reemplaza al rango de 5 a 30 minutos declarado sin fuente en el')
    print('  Capítulo 1, y constituye una medición propia y no una estimación.')
    print()
    print('  Debe reportarse junto con dos limitaciones: (i) el tiempo se midió sobre un')
    print('  operador que conocía el sistema, por lo que subestima el de un operador no')
    print('  entrenado; y (ii) el término de comparación automatizado (%s s) proviene de' % co(E1_E2E_MEDIA, 3))
    print('  un entorno de laboratorio sin latencia de servicios externos, por lo que el')
    print('  factor de mejora obtenido debe leerse como una cota superior.')
    print()


if __name__ == '__main__':
    main()
