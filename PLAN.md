# Plan: Motor de agentes de venta con IA (multi-vertical)

> Un solo motor de agentes, varios negocios encima. Primer vertical:
> **seguros**. Desde el día 1 quedan definidas las bases de **trading** y
> **Preparatoria CROC** para activarlas sin reescribir código.
>
> Reanálisis desde cero del sistema descrito en el transcript, adaptado a
> un solo operador.

---

## 1. Diagnóstico del transcript (qué sirve y qué no)

El sistema del transcript (Paperclip + Obsidian + Supabase + Deep Infra +
ElevenLabs + Hermes + MCPs) está diseñado para un **holding con varias
divisiones y un call center humano**. Para un solo operador trae
sobre-ingeniería, pero tiene una idea que vale oro y que aquí se vuelve el
centro del diseño: **construir el motor una vez y clonarlo por negocio**.

| Componente / idea | ¿Sirve solo? | Nota |
|---|---|---|
| Agentes especialistas por división | Sí, adaptado | Aquí son **verticales** (seguros, trading, prepa) y dentro de cada uno, sub-productos (ramo de seguro, tipo de cuenta, modalidad). |
| CFO + Router de modelos | Sí | Clave para no quebrar en tokens. Presupuesto **por vertical**. |
| Supabase vectorial | Sí | Memoria. No negociable. |
| Obsidian | **No** | Útil para diseñar, no se necesita en producción. Opcional y personal. |
| Paperclip | Opcional | Útil para prototipar; el motor se construye en código propio. |
| Voz (ElevenLabs) | Sí, Fase 3 | Primero que convierta por texto. |
| Avatar en video | Sí, Fase 3 | Uno distinto por vertical. |
| 120 agentes | **No** | 7 agentes genéricos bien hechos, parametrizados por vertical. |
| Aprendizaje por feedback (Hermes) | Sí, Fase 4 | Cuando haya volumen. Y aprende **entre** verticales. |
| Llamada en <2 min post-registro | Sí | Regla de oro de ventas, en cualquier vertical. |
| Aparecer en ChatGPT/Claude (AEO) | Sí | El nuevo SEO. |
| "El que se escriba el manual mientras se construye" | Sí | Agente `Scribe`. |

### Lo que el transcript NO cubre y es crítico

1. **Cumplimiento regulatorio distinto por vertical.** Seguros (CNSF),
   trading (CNBV y el regulador del broker), educación (SEP / PROFECO).
   El bot puede educar, pre-calificar y agendar; **el cierre siempre lo
   hace un humano autorizado**.
2. **Pre-calificación con descarte responsable.** No todo prospecto debe
   avanzar: alguien que invertiría dinero prestado, o que no tiene
   certificado de secundaria, necesita otra salida, no un cierre.
3. **Ciclos largos y por temporada** (renovaciones, periodos de
   inscripción). El *nurture* importa más que el primer contacto.
4. **Confianza > velocidad.** Un bot que educa y acompaña convierte; uno
   que presiona espanta.
5. **El dinero real es recurrente**: renovaciones, comisión por volumen,
   reinscripciones.

---

## 2. La idea central: un motor, N verticales

**Regla de oro: el código del motor no sabe qué vende.** Todo lo que
depende del negocio vive en `verticales/<id>/vertical.yaml`.

**Prueba de que la base está bien hecha:** activar un vertical nuevo =
copiar `verticales/_plantilla/`, llenarla, y cero cambios en el código
del motor. Si para el segundo vertical hay que tocar el motor, se corrige
el motor (se generaliza), nunca se parcha con un `if vertical == ...`.

### 2.1 Qué es común y qué cambia

| Pieza | Motor (común, código) | Vertical (config YAML) |
|---|---|---|
| Agentes | Lógica, memoria, herramientas | Nombre, tono, presentación |
| Base de datos | Mismas tablas con `vertical_id` | — |
| Calificación | Motor de scoring | Preguntas, pesos, descartes, redirecciones |
| Cumplimiento | Guardrail que revisa cada mensaje saliente | "Nunca decir", disclaimer, quién cierra, consentimientos |
| Contacto | Scheduler por zona horaria del prospecto | Ventana, días, canal, cadencia |
| Conocimiento | Ingesta, embeddings, búsqueda | Fuentes y búsquedas de YouTube |
| Acompañamiento | Motor de eventos sobre clientes | Eventos (renovación, inactividad, reinscripción…) |
| Contenido | Generador y publicador | Redes, pilares, avatar |
| Costos | Router + tope diario | Presupuesto diario |
| KPIs | Dashboard | Metas |

### 2.2 Los tres verticales lado a lado

| | Seguros | Trading | Preparatoria CROC |
|---|---|---|---|
| Qué se vende | Pólizas (ramo inicial por definir; auto recomendado) | Apertura de cuenta con broker aliado (modelo referidor / IB) + formación | Inscripción a bachillerato |
| Quién compra | Particular o pyme | Adulto 20–35 con capital de riesgo | Adulto que no terminó la prepa, o padre/madre de adolescente |
| Dolor que abre la conversación | "Si choco o me enfermo, ¿quién paga?" | "Mi dinero no crece y no sé por dónde empezar" | "Sin certificado no me ascienden" |
| Regla dura | Cédula CNSF para cerrar | Prohibido prometer rendimientos o recomendar operaciones (asesoría regulada) | RVOE vigente; datos de menores con tutor |
| Quién cierra | Agente con cédula (tú o broker) | Ejecutivo del broker o tú como referidor | Asesor educativo / control escolar |
| Ciclo de venta | 1–4 semanas | Días | 1–6 semanas, por temporada de inscripción |
| Dinero recurrente | Renovación anual + otros ramos | Comisión por volumen operado | Colegiaturas + reinscripción |
| El acompañante vigila | Vencimientos, eventos de vida, siniestros | Inactividad, pérdidas fuertes, retiros | Asistencia, pagos, reinscripción, deserción |
| Línea roja ética | Vender cobertura que no aplica | Incitar a depositar tras pérdidas o con dinero prestado | Falsa urgencia ("últimos lugares"), prometer certificado rápido |

Configuración completa de cada uno: `verticales/seguros/`,
`verticales/trading/`, `verticales/preparatoria-croc/`. Todo lo marcado
`POR CONFIRMAR` hay que llenarlo antes de pasar de `borrador` a `piloto`.

### 2.3 Reglas de separación entre verticales

- **Una marca, un número de WhatsApp y una voz/avatar por vertical.** Un
  prospecto de la prepa jamás recibe un mensaje de trading.
- **Datos aislados** por `vertical_id` + Row Level Security. Cross-sell
  entre verticales solo con consentimiento explícito del cliente.
- **Presupuesto de IA por vertical**: si trading se come su tope, no
  apaga a seguros.
- **El agente siempre se presenta como asistente virtual**, en todos los
  verticales.
- **Si un vertical es de un tercero** (p. ej. la prepa es tu cliente y no
  tu negocio), el mismo motor se despliega en una instancia separada con
  su propia base de datos. Por eso nada de negocio va en el código.

### 2.4 Orden de lanzamiento: bases juntas, lanzamientos uno a la vez

Las bases de los tres se hacen ya. Los lanzamientos van escalonados:

1. **Seguros** (semanas 2–5): valida el motor.
2. **Segundo vertical** (semanas 6–9): valida la plantilla.
3. **Tercer vertical** (semanas 10–13).

¿Cuál va segundo? **El que tenga la fecha más cercana.** Si el próximo
periodo de inscripción de la prepa cae en los próximos 2–3 meses, la prepa
va segunda; si no, trading.

¿Por qué no los tres en piloto al mismo tiempo? Tres fuentes de bugs, tres
marcos regulatorios y tú solo para cerrar. Cada lanzamiento además
mejora el motor para el siguiente.

---

## 3. Stack y costos

| Capa | Herramienta | Costo mensual estimado |
|---|---|---|
| Agentes / orquestación | **Pydantic AI** o **LangGraph** en Python (código propio) | $0 |
| Router de modelos | **OpenRouter** (cientos de modelos, una sola API) | pay-per-use, ~$20–50 USD |
| Base de datos vectorial | **Supabase** (Postgres + pgvector) | $0–25 USD |
| Scraping / transcripción | **Apify** o **Firecrawl** | ~$15 USD |
| Hosting | **Railway** o **Fly.io** (staging + producción) | ~$10–20 USD |
| WhatsApp Business API | **Twilio** o **WATI** | ~$30 USD + mensajes |
| Agenda | **Cal.com** | $0 |
| Voz (Fase 3) | **ElevenLabs** o **Cartesia** | ~$22 USD |
| Avatar video (Fase 3) | **HeyGen** o **Synthesia** | ~$30–90 USD |
| Repositorio / CI | **GitHub** | $0 |

- **Motor + seguros (Fase 1):** ~$80–100 USD/mes.
- **Cada vertical adicional:** ~$40–80 USD/mes (número de WhatsApp y
  mensajes, uso de LLM, avatar propio). No es tan barato como "10 dólares"
  porque cada marca necesita su propio número y su propia cara.
- **Tres verticales con voz y avatar:** ~$300–400 USD/mes.

Son estimaciones; se confirman al dar de alta cada servicio.

**Dos ambientes desde el día 1:** `staging` (pruebas) y `production`
(clientes reales). Mismo stack, proyectos duplicados.

---

## 4. Los agentes (7 genéricos + Scribe)

Cada agente es **código genérico** que lee su comportamiento del
`vertical.yaml` del lead que está atendiendo. En Fase 1 solo corren 4.

| Agente | Qué hace | Lee del vertical | Fase |
|---|---|---|---|
| `Router` | Decide qué agente atiende y qué modelo LLM usar; corta si se excede el presupuesto | `presupuesto_ia_diario_usd` | 1 |
| `Scout` | Enriquece al lead (fuentes públicas, IP → zona horaria) y escribe un brief de 10 líneas | `cliente_ideal`, `calificacion.descartar_si` | 1 |
| `Greeter` | Primer contacto en <2 min dentro de horario. No vende: confirma identidad, pregunta el dolor, califica, agenda | `marca`, `contacto`, `calificacion` | 1 |
| `Expert` | Uno por vertical. Lee sus fuentes a diario y mantiene el conocimiento al día en Supabase | `conocimiento` | 1 |
| `Advisor` | Resuelve dudas con información citada de Supabase; siempre agrega el disclaimer y pasa al humano para cerrar | `cumplimiento` | 2 |
| `Creator` | Publica contenido diario por vertical, para SEO y AEO | `contenido` | 2 |
| `Shepherd` | Acompaña a clientes cerrados según los eventos del vertical | `acompanamiento` | 2 |
| `Scribe` | Mantiene `OPERATIONS.md` al día leyendo commits, prompts y tablas | — | 1 |

Por encima de todos corre el **guardrail de cumplimiento**: ningún
mensaje sale sin pasar por la lista `cumplimiento.nunca_decir` del
vertical. Si choca, el mensaje se bloquea, se registra y se escala al
humano.

---

## 5. Flujo end-to-end (igual para todos los verticales)

```
[Anuncio / orgánico / referido]  →  landing de la marca del vertical
        ↓
[Webhook con vertical_id]  →  Scout: enriquecimiento + brief (20 s)
        ↓
[Router: ¿dentro de la ventana horaria del vertical y del prospecto?]
     ├── Sí → Greeter contacta en <2 min
     └── No → se programa para el inicio de la siguiente ventana
        ↓
[Greeter califica con las preguntas del vertical]
     ├── Puntaje ≥ mínimo → agenda con el humano que cierra
     ├── Cae en "redirigir_si" → salida útil (INEA, contenido gratis…)
     ├── Cae en "descartar_si" → se descarta con amabilidad
     └── No contesta → cadencia de seguimiento del vertical
        ↓
[Cierre humano: póliza / cuenta / inscripción]
        ↓
[Shepherd: eventos del vertical]  →  renovación, reinscripción, referidos
```

Todo queda en Supabase (`db/schema.sql`), que funciona como CRM mínimo
desde la Fase 1.

---

## 6. Plan de trabajo por fases

### Fase 0 — Preparación (semana 1)
- [ ] Llenar los `POR CONFIRMAR` de `verticales/seguros/vertical.yaml`.
- [ ] Seguros: cédula de agente ante la CNSF, o convenio con un broker
      que te permita operar bajo su figura.
- [ ] Trading: convenio de referidor (IB) con un broker regulado;
      verificar que pueda captar clientes en México y qué puede decir un
      referidor.
- [ ] Preparatoria CROC: confirmar si vendes como promotor o la escuela
      es tu cliente; RVOE, planteles, modalidades, costos, fechas de
      inscripción y permiso de uso de marca.
- [ ] Dar de alta Supabase, OpenRouter, Railway, Apify y proveedor de
      WhatsApp.
- [ ] Aplicar `db/schema.sql` en staging.

### Fase 1 — Motor + seguros (semanas 2–5)
- [ ] Cargador de verticales: lee `verticales/*/vertical.yaml`, valida
      los campos obligatorios contra la plantilla y se niega a activar un
      vertical en `piloto` que tenga `POR CONFIRMAR`.
- [ ] Router, Scout, Greeter y Expert, todos parametrizados por vertical.
- [ ] Guardrail de cumplimiento sobre cada mensaje saliente.
- [ ] Scheduler de contacto por zona horaria con cola fuera de horario.
- [ ] Landing + webhook + WhatsApp + Cal.com para seguros.
- [ ] Scribe generando `OPERATIONS.md`.
- **Meta:** 10 leads reales, 3 cotizaciones, 1 póliza. Y ninguna mención
  a "seguro" en el código del motor fuera de `verticales/seguros/`.

### Fase 2 — Segundo vertical + contenido (semanas 6–9)
- [ ] Activar el segundo vertical **solo** con su config, landing y
      número de WhatsApp. Cualquier cambio de motor que haga falta se
      documenta como deuda de la plantilla y se generaliza.
- [ ] Advisor y Shepherd activos en seguros y en el segundo vertical.
- [ ] Creator publicando por vertical.
- [ ] Dashboard de KPIs filtrable por vertical.
- **Meta:** segundo vertical procesando leads reales sin cambios al motor.

### Fase 3 — Tercer vertical, voz y avatar (semanas 10–13)
- [ ] Activar el tercer vertical.
- [ ] Voz y avatar distintos por vertical (perfil joven para trading,
      asesor educativo cercano para la prepa, perfil confiable para
      seguros).
- [ ] Llamada por voz como canal secundario; WhatsApp sigue siendo el
      principal.
- **Meta:** tres verticales operando, costo por cierre medido en cada uno.

### Fase 4 — Aprendizaje y escala (mes 4 en adelante)
- [ ] Feedback loop: cada interacción se califica y los guiones
      ganadores alimentan a los agentes.
- [ ] **Aprendizaje cruzado:** lo que el Greeter de seguros aprende sobre
      cómo abrir una conversación mejora al de la prepa y al de trading.
      Ese es el verdadero valor del motor común.
- [ ] Nuevos sub-productos (otros ramos, otras modalidades) y nuevos
      verticales = nuevas carpetas.

---

## 7. KPIs (por vertical, desde la Fase 1)

Comunes:
- Tiempo registro → primer contacto (meta: <2 min en horario).
- Tasa de respuesta en WhatsApp (meta: >40%).
- Tasa de calificación (agendados / leads).
- Costo por lead (CPL) y por cierre (CPA).
- Costo de IA diario contra presupuesto.
- Mensajes bloqueados por el guardrail (debe tender a cero).

Propios de cada vertical (metas iniciales en cada `vertical.yaml`):
- Seguros: cotizaciones, pólizas, renovación año 1.
- Trading: cuentas abiertas, cuentas fondeadas, clientes activos a 90 días.
- Prepa: citas, inscripciones, retención por periodo.

---

## 8. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Un regulador detecta que un bot "asesora" o cierra | Guardrail + disclaimer + humano autorizado en el cierre, en los tres verticales. |
| Trading: promesa de rendimientos o clientes vulnerables | Descarte por dinero prestado o fondo de emergencia; prohibido sugerir depósitos tras pérdidas; retiros siempre al humano. |
| Prepa: datos de menores | Contacto con madre, padre o tutor; consentimiento registrado en `leads.consentimientos`. |
| Prepa: uso de la marca CROC sin autorización | Confirmar el permiso antes de publicar cualquier anuncio. |
| Alucinación sobre coberturas, planes o condiciones | El Advisor solo responde con información citada de Supabase; logs auditables. |
| Fuga de datos personales | RLS en todas las tablas, cifrado en reposo, nada de datos personales a modelos externos sin anonimizar. |
| Mezcla de verticales | `vertical_id` obligatorio en cada tabla; marcas y números separados. |
| Dependencia de un proveedor LLM | OpenRouter como capa intermedia. |
| Te quemas manteniéndolo solo | Lanzamientos escalonados + Scribe + `OPERATIONS.md`. |

---

## 9. Qué construir esta semana

1. Llenar los `POR CONFIRMAR` del vertical de seguros.
2. Crear el proyecto de Supabase de staging y aplicar `db/schema.sql`.
3. Agregar `src/` con Pydantic AI y un primer agente `scout.py` que
   reciba un JSON de lead más su `vertical.yaml` y devuelva un brief.
4. Comprar el dominio de la marca de seguros y armar un landing de una
   página con formulario.
5. Dejar OpenRouter con límite de gasto diario.

---

## 10. Lo que no copio del transcript (y por qué)

- **No 15 agentes el día 1.** Un sistema que una persona no puede
  explicar en una hoja no lo puede mantener.
- **No avatar en Fase 1.** 10 videos cortos con tu cara real convierten
  mejor que un clon mientras no haya volumen.
- **No white label de un tercero.** Construirlo tú (con Claude Code al
  lado) te hace dueño de cada pieza y del aprendizaje del negocio.
- **No llamada automatizada como canal principal.** En LATAM, WhatsApp
  convierte más y asusta menos.

---

## Archivos de este repo

| Archivo | Para qué |
|---|---|
| `PLAN.md` | Este plan |
| `db/schema.sql` | Esquema de Supabase multi-vertical (tablas, índices, RLS) |
| `verticales/_plantilla/vertical.yaml` | Plantilla comentada para crear un vertical nuevo |
| `verticales/seguros/vertical.yaml` | Borrador del vertical de seguros |
| `verticales/trading/vertical.yaml` | Borrador del vertical de trading |
| `verticales/preparatoria-croc/vertical.yaml` | Borrador del vertical de Preparatoria CROC |
