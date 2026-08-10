# D-4 — Agregar el nodo `Registrar Notificación Sin Stock` al Flujo 1

**Origen:** verificación B-6.1 del plan (`docs/PLAN_REGENERACION_EVIDENCIA.md` §13).
**Estado:** pendiente de aplicar en la UI de n8n.
**Gobernanza:** cambio del sistema construido — se documenta como tal en la tesis.

---

## El problema

La rama sin stock del Flujo 1 termina así:

```
Marcar Sin Stock → Enviar Email Sin Stock → Respuesta Sin Stock
```

La rama con stock, en cambio, tiene un paso más:

```
Confirmar Orden → Enviar Email Confirmación → Registrar Notificación → Respuesta Confirmada
                                              ^^^^^^^^^^^^^^^^^^^^^^
                                              UPDATE orders SET notified_at = NOW()
```

Resultado: **las órdenes `no_stock` nunca reciben `notified_at`**, y su MTTR es NULL. Confirmado en la BD: la única orden `no_stock` real (`ORD-DEMO-02`) lo tiene vacío.

Peor todavía, es un fallo silencioso: `v_metrics_summary` calcula el MTTR con `WHERE notified_at IS NOT NULL`, así que **excluye esas órdenes sin avisar** y el promedio sale medido solo sobre la rama feliz.

Y `Respuesta Sin Stock` le contesta al cliente `"Se notificó al cliente"` — una afirmación que ninguna fila respalda.

---

## Cómo aplicarlo (UI de n8n — http://localhost:5678)

1. Abrir el workflow **`Flujo 1 — Pipeline de Procesamiento de Órdenes`** (el SIMPLE, el que está activo).
2. Copiar el bloque JSON de abajo al portapapeles.
3. Click en cualquier parte vacía del canvas y pegar (**Ctrl+V**). n8n crea el nodo con todo configurado.
4. **Reconectar la rama sin stock** para que quede:

   ```
   Marcar Sin Stock → Enviar Email Sin Stock → Registrar Notificación Sin Stock → Respuesta Sin Stock
   ```

   Concretamente: borrar la conexión `Enviar Email Sin Stock → Respuesta Sin Stock`, y crear
   `Enviar Email Sin Stock → Registrar Notificación Sin Stock → Respuesta Sin Stock`.
5. Verificar que el nodo nuevo tenga asignada la credencial **`Postgres account`** (debería tomarla sola; si no, seleccionarla del desplegable).
6. **Guardar** el workflow.
7. Exportar (**Download**) y reemplazar `workflows/Flujo 1 — Pipeline de Procesamiento de Órdenes SIMPLE.json` en el repo.

### Nodo a pegar

```json
{
  "nodes": [
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "UPDATE orders\nSET notified_at = NOW()\nWHERE id = {{ $('Registrar Orden').item.json.order_id }}\nRETURNING id AS order_id, notified_at;",
        "options": {}
      },
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.5,
      "position": [-1448, 672],
      "name": "Registrar Notificación Sin Stock",
      "credentials": {
        "postgres": {
          "id": "3VBjtgn4ueU5ZLRx",
          "name": "Postgres account"
        }
      }
    }
  ],
  "connections": {}
}
```

La query es **idéntica** a la del nodo `Registrar Notificación` de la rama con stock. Misma referencia (`$('Registrar Orden').item.json.order_id`), misma credencial, mismo `typeVersion`. No introduce lógica nueva: cierra la simetría que faltaba.

---

## Cómo verificar que quedó bien

Después de guardar, disparar una orden que fuerce la rama sin stock (pedir más unidades de las que hay):

```powershell
Invoke-RestMethod -Uri "http://localhost:5678/webhook/orden-nueva" -Method POST `
  -ContentType "application/json" `
  -Body '{"order_number":"ORD-VERIF-D4","customer_name":"Verificacion D4","customer_email":"verif@example.com","customer_phone":"5492610000000","product_sku":"PROD-014","quantity":999}'
```

Y comprobar que `notified_at` quedó cargado:

```sql
SELECT order_number, status, received_at, processed_at, notified_at,
       EXTRACT(EPOCH FROM (notified_at - processed_at)) AS mttr_seg
FROM orders WHERE order_number = 'ORD-VERIF-D4';
```

**Criterio de éxito:** `status = 'no_stock'` **y** `notified_at` no nulo.

> La fila de verificación queda con `data_source = 'measured'` (es una ejecución real). Se puede borrar después, o dejarla — de todos modos la BD se limpia en B-4 antes de correr E1.

---

## Qué escribir en la tesis

Este cambio hay que declararlo, no esconderlo. Redacción sugerida para §4.4 (o donde se describa el Flujo 1):

> Durante la fase de validación experimental se detectó que la rama de "sin stock" del pipeline no registraba la marca temporal de notificación (`notified_at`), lo que impedía calcular el MTTR para ese subconjunto de órdenes. Se incorporó el nodo `Registrar Notificación Sin Stock`, simétrico al ya existente en la rama de confirmación, de modo que ambas ramas instrumenten el pipeline completo. El workflow pasó de 12 a 13 nodos.

Y actualizar el conteo de nodos del Flujo 1 (**12 → 13**) en todos los lugares donde aparezca.
