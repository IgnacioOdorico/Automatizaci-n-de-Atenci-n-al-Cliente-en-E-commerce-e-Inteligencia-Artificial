# E4 — Baseline de atención manual

Cierra los hallazgos **C-09** y **A-09**, y le da fundamento al denominador de **H1**.

Ver `docs/PLAN_REGENERACION_EVIDENCIA.md` §6 y §12 (D-5).

---

## Qué problema resuelve

H1 afirma que el pipeline reduce el tiempo end-to-end *"frente al rango de 5 a 30 minutos que caracteriza al procesamiento manual en PyMEs de e-commerce de escala similar"*.

**Ese rango no está medido, no está citado y no aparece en el marco teórico.** Es el denominador de todas las afirmaciones de impacto del trabajo: el factor de mejora de §5.4, el porcentaje de §6.1 y la comparación del resumen. El auditor lo marcó textualmente:

> *"Ese rango no tiene cita, no aparece en el marco teórico y no corresponde a ninguna medición realizada en este estudio."* — C-09

E4 lo reemplaza por **un dato propio, medido con cronómetro por los autores**.

---

## Diseño

Un operador humano procesa **12 órdenes** a mano, contra la misma base de datos y el mismo catálogo que usa el Flujo 1, cronometrando cada fase.

### Las dos decisiones que definen el número (tomadas el 2026-08-13)

Ambas se resolvieron eligiendo **el escenario que menos favorece a la hipótesis**. Es deliberado: si el sistema gana igual, el resultado no es discutible.

| Decisión | Resuelto | Por qué |
|---|---|---|
| **Redacción del email** | **Plantilla fija + completar 5 campos** (`plantilla_email.txt`) | Representa una PyME con un proceso mínimo establecido, no una sin ningún proceso. Es el supuesto conservador: baja el denominador y por lo tanto baja el factor de mejora. La alternativa —redactar desde cero— habría inflado el resultado y es atacable ("ninguna PyME real trabaja así"). |
| **Alcance del cronómetro** | **Solo procesamiento.** Desde que el operador *ve* la orden hasta que termina de redactar el email. | La latencia de detección (cada cuánto un operador revisa la bandeja) no es medible sin convertirla en un parámetro elegido por nosotros — que es exactamente el defecto que estamos corrigiendo. **Se declara aparte como supuesto explícito**, nunca sumada dentro del número medido. |

> **Regla que ordena todo E4:** lo medido y lo supuesto no se mezclan jamás en la misma cifra. Ese fue el mecanismo del hallazgo C-08.

### Las tres fases que se cronometran

| Fase | Qué hace el operador | Dónde |
|---|---|---|
| **T1 — Lectura y verificación** | Lee la orden y consulta el stock disponible del producto | `psql` |
| **T2 — Actualización** | Descuenta stock y marca `confirmed`, o marca `no_stock` | `psql` |
| **T3 — Redacción** | Completa la plantilla con los 5 datos del cliente | El cronómetro |

**Total por orden = T1 + T2 + T3.** El desglose importa tanto como el total: muestra *dónde* se va el tiempo manual, y eso es material de análisis para el Cap. 5, no solo un número.

### n = 12, y los 2 primeros se reportan aparte

El plan §6 pedía 10. Se hacen **12** por el efecto de aprendizaje: el operador es mucho más lento en las primeras órdenes, mientras se acomoda al procedimiento.

**Los 2 primeros son de familiarización. No se descartan: se reportan por separado.** Es el mismo criterio con el que E1 trató el *cold start* (§14.2): *"se reporta y se justifica, no se borra"*. Ocultar las primeras mediciones sería maquillar el dato; declararlas y excluirlas del promedio principal con la razón escrita es metodología.

El resultado primario sale de las **10 órdenes restantes** — que es exactamente la n que pedía el plan.

### Composición de la muestra

9 órdenes con stock y 3 sin stock (75 / 25), próxima a la distribución real de E1.a (70 / 30). Las dos ramas cuestan distinto trabajo manual y la muestra tiene que reflejar las dos, igual que el E2E automatizado.

---

## ⚠️ Trampa crítica: estas órdenes NO deben contaminar E1

Las 12 órdenes de E4 se insertan en la misma tabla `orders` que usa el Flujo 1, y llevan `processed_at` / `notified_at` **a escala humana (minutos)**. Si entran a las queries de E1, destruyen el MTTD y el MTTR medidos.

**Por eso se marcan con `data_source = 'e4_manual'`**, un valor distinto de `'measured'` (E1/E2) y de `'synthetic'` (seed).

> **Toda query de E1 en el Cap. 5 debe filtrar `data_source = 'measured'`.** Es la misma disciplina que exige D-10 sobre `interactions`. Verificalo antes de recapturar cualquier figura en E5.

---

## Cómo se ejecuta

### 1. Levantar el entorno

```powershell
docker compose up -d
docker compose ps          # los 4 servicios en Up
```

### 2. Crear las 12 órdenes

```powershell
Get-Content experiments\E4\preparar_e4.sql | docker exec -i tesis_postgres psql -U n8n_user -d ecommerce_tesis
```

El script imprime al final las 12 órdenes creadas, para verificar que quedaron todas en `pending`.

> ⚠️ **Esa salida no muestra el stock ni la rama que le toca a cada orden, a propósito.** Averiguar si hay stock *es* el trabajo que mide T1. Si el operador ya lo sabe antes de arrancar el cronómetro, T1 queda subestimada y la medición no vale. Se descubre consultando, no leyendo la tabla.

> El script es idempotente: si las órdenes `ORD-E4-*` ya existen, aborta sin tocar nada. Para rehacer la medición hay que borrarlas explícitamente (la sentencia está comentada al final del archivo).

### 3. Abrir el cronómetro

Abrí `experiments/E4/cronometro.html` en el navegador. No necesita servidor ni conexión.

Al lado, dejá abierta una consola de `psql`:

```powershell
docker exec -it tesis_postgres psql -U n8n_user -d ecommerce_tesis
```

### 4. Procesar las 12 órdenes

Para cada una, el cronómetro te muestra los datos de la orden y las consultas exactas a correr. Vos hacés el trabajo real en `psql`, completás el email, y marcás el fin de cada fase.

**Reglas de la medición — leelas antes de arrancar:**

- **Trabajá a ritmo normal de trabajo.** Ni apurado ni distraído. Un baseline apurado es tan falso como uno inflado.
- **No preparés nada de antemano.** Nada de tener las queries ya escritas en el portapapeles.
- **Si te interrumpen, descartá esa orden** y anotalo. El botón `Descartar` la marca y sigue con la siguiente.
- **No mires este README durante la medición.** Leelo entero antes, una vez.

### 5. Exportar y analizar

Al terminar, el botón `Descargar CSV` genera `e4_tiempos_<sello>.csv`. Guardalo en `experiments/E4/resultados/` y corré:

```powershell
python experiments\E4\analizar_e4.py experiments\E4\resultados\e4_tiempos_<sello>.csv
```

---

## Cómo se usa el resultado — y la advertencia que va con él

E4 produce el denominador. El numerador ya está medido: **E2E = 0,063 s** (E1.a, n = 50, §14.2).

> ### ⚠️ El factor va a dar un número enorme. No lo pongas de titular.
>
> Con un baseline manual de entre 2 y 5 minutos, el factor contra 0,063 s cae en el orden de **2.000x a 5.000x**.
>
> **El numerador está artificialmente bajo.** Los 0,063 s son de un pipeline local: Mailpit en lugar de un SMTP real, sin APIs externas, sin red. Un despliegue productivo sumaría latencia de correo y de servicios de terceros. **El factor medido es una cota superior, no el factor real.**
>
> Y hay un problema de credibilidad encima del metodológico: la tesis ya fue castigada por declarar 190x cuando correspondía 31,6x (C-08). **Volver con un titular de "3.000x" ante el mismo tribunal es pedir que te lo revisen con lupa** — y esta vez tendrían razón.

**Cómo reportarlo, en este orden:**

1. **Primero, la afirmación falsable de H1: "menos de 30 segundos".** Medido: 0,063 s. Se cumple con un margen de ~476x contra el umbral que el propio trabajo se fijó. **Esta es la contrastación de la hipótesis** y no depende del baseline manual.
2. **Después, el factor contra el baseline medido**, acompañado *en la misma oración* de la limitación del entorno de laboratorio.
3. **Aparte, la latencia de detección** como supuesto declarado, con su impacto calculado — nunca dentro del número medido.

Redactado así, E4 deja de ser un riesgo y pasa a ser una demostración de criterio: **el equipo midió su propio baseline y declaró por qué su resultado más vistoso está sobreestimado.** Eso vale más ante un tribunal que cualquier factor grande.

---

## Archivos

| Archivo | Qué es |
|---|---|
| `preparar_e4.sql` | Crea las 12 órdenes en `pending` con `data_source = 'e4_manual'` |
| `plantilla_email.txt` | La plantilla fija (decisión conservadora del email) |
| `cronometro.html` | Instrumento de medición. Autónomo, sin dependencias |
| `analizar_e4.py` | Estadísticos por fase, IC por t de Student, y el cálculo del factor con sus caveats |
| `resultados/` | Salidas crudas. Se commitean sin editar |
