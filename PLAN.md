# Plan: Agente de Ventas de Seguros con IA (operador solo)

> Reanálisis desde cero del sistema descrito en el transcript, adaptado a un
> solo operador en el sector asegurador. Lo que sigue no es "lo mismo pero
> con seguros": es una re-arquitectura pensada para que una persona lo
> pueda construir, mantener y rentabilizar.

---

## 1. Diagnóstico del transcript (qué sirve y qué no)

El sistema que Chava describe (Paperclip + Obsidian + Supabase + Deep Infra
+ ElevenLabs + Hermes + MCPs) está diseñado para un **holding con varias
divisiones y call center humano**. Trae decisiones que para un solo
operador son sobre-ingeniería:

| Componente / idea | ¿Sirve solo? | Nota |
|---|---|---|
| Agentes especialistas por división | Parcial | Tú no tienes 5 divisiones. Tienes **ramos** de seguro (auto, vida, GMM, hogar, empresa). Mismo patrón, pero más chico. |
| CFO + Router (Deep Infra) | Sí | Clave para no quebrar en tokens. Lo mantengo. |
| Supabase vectorial | Sí | Memoria. No negociable. |
| Obsidian como "cerebro visual" | **No** | Es útil para humanos que diseñan. No se necesita en producción. Opcional, personal. |
| Paperclip | Opcional | Útil para prototipar. Puede migrar a código propio en LangGraph / Pydantic AI más adelante. |
| ElevenLabs (voz) | Sí, pero no al inicio | Solo cuando ya tengas un flujo que convierta por texto. |
| Avatar en video (clon) | Sí, en Fase 3 | En seguros el video del asesor genera confianza — es diferencial. |
| 120 agentes diarios | **No** | Chava corre 120 porque es trading automatizado. Tú con 4–6 agentes bien hechos ganas. |
| Hermes (self-learning) | Sí, en Fase 4 | Después de que tengas suficiente volumen (>200 llamadas / mes) para que valga la pena. |
| Call center humano | **No aplica** | En tu caso **tú eres el único cerrador** al inicio, o le pasas al broker/aseguradora. |
| Llamada en <2 min post-registro | Sí | Es la regla de oro de ventas que sí sobrevive. |
| MCPs con ChatGPT/Claude para que te encuentren | Sí | AEO (Answer Engine Optimization) es el nuevo SEO. |

### Lo que el transcript **NO** cubre y es crítico en seguros

1. **Cumplimiento regulatorio (CNSF en México, o equivalente local).** No puedes
   dar "asesoría" sin cédula. El agente IA puede educar, pre-calificar y
   agendar — **no cotizar vinculante ni emitir pólizas sin un humano con cédula
   atrás.** Esto cambia el diseño.
2. **Pre-calificación por riesgo**, no solo por interés. En trading todo el
   mundo puede abrir cuenta; en seguros una aseguradora puede rechazar al
   prospecto. Hay que filtrar antes de gastar tiempo.
3. **Ciclos largos** (semanas, no horas). La automatización de *nurture* es
   más importante que la del primer contacto.
4. **Confianza > velocidad.** Un bot que "cierra" en seguros espanta. Un
   bot que *educa, agenda y acompaña* convierte.
5. **Renovaciones y cross-sell anual.** El dinero real está en el *lifetime
   value*, no en la venta inicial.

---

## 2. Decisiones de arquitectura (versión 1 operable por una persona)

### 2.1 Elige UN ramo para empezar

Es el error #1 de los que arrancan. No construyas "el agente de seguros",
construye **"el agente de GMM para familias de clase media en CDMX"**, o
"el agente de seguro de auto para flotillas pyme". Nicho estrecho =
knowledge base manejable, prospectos reconocibles, cierre más rápido.

**Recomendación:** empieza por **un ramo donde ya tengas red o experiencia
propia**. Si no la tienes, el ramo de más baja fricción para empezar es
**auto** (producto estandarizado, mucha demanda, comparadores públicos,
ciclo corto). Vida y GMM pagan más pero exigen más confianza.

### 2.2 Stack mínimo viable

| Capa | Herramienta | Costo mensual estimado |
|---|---|---|
| Agentes / orquestación | **Pydantic AI** o **LangGraph** en Python (código tuyo, no Paperclip) | $0 |
| LLM router | **OpenRouter** (equivalente moderno a Deep Infra, 300+ modelos) | pay-per-use, ~$20–50 USD |
| Base de datos vectorial | **Supabase** (pgvector) | $0–25 USD |
| Scraping / transcripción | **Apify** o **Firecrawl** | ~$15 USD |
| Hosting | **Railway** o **Fly.io** (1 VPS chico + staging) | ~$10–20 USD |
| Voz (Fase 3) | **ElevenLabs** o **Cartesia** | ~$22 USD |
| WhatsApp Business API | **Twilio** o **WATI** | ~$30 USD + mensajes |
| Avatar video (Fase 3) | **HeyGen** o **Synthesia** | ~$30–90 USD |
| Repositorio / CI | **GitHub** | $0 |

**Costo mensual Fase 1 (sin voz ni avatar): ~$80–100 USD.**
**Costo mensual Fase 3 completa: ~$200–250 USD.**

Está muy debajo de los $150 que gasta Chava en Trading Hearts porque tu
volumen es menor. Cuando crezcas, escala.

### 2.3 Dos ambientes desde el día 1

- `staging` (donde pruebas cambios)
- `production` (donde atiendes clientes reales)

Chava tiene razón: no es caro y te salva de catástrofes. Mismo stack,
proyecto duplicado en Supabase y Railway.

---

## 3. Los agentes que sí necesitas (7, no 15 — y solo 4 en Fase 1)

Diseñados para que **cada uno haga una cosa bien** y se comuniquen entre
sí vía la base vectorial (memoria compartida) y un orquestador.

### 3.1 Orquestador (`Router`)
Decide qué agente responde a cada mensaje entrante. También elige el
modelo LLM óptimo (barato para clasificar, bueno para redactar, caro
solo para razonar). Tiene un presupuesto diario tope (ej. $3 USD/día) y
corta si se excede.

### 3.2 Investigador de prospecto (`Scout`)
Al llegar un lead con nombre + teléfono + email, hace:
- Enriquecimiento con fuentes públicas (LinkedIn público, Instagram público,
  web de la empresa si aplica, Google).
- Clasifica: particular / pyme, rango de edad probable, zona geográfica
  (vía IP + código postal del formulario), señales de capacidad de pago.
- Marca banderas rojas (ej. perfil inconsistente, bot, lead quemado).
- Escribe un **brief de 10 líneas** en Supabase sobre el prospecto.

### 3.3 Educador / Primer contacto (`Greeter`)
WhatsApp o llamada corta (<2 min desde registro, respetando horario local).
**No vende.** Hace tres cosas:
1. Confirma que es la persona correcta.
2. Pregunta *qué le preocupa* (dolor, no producto).
3. Agenda una llamada corta con el humano (tú) o con el `Advisor` IA
   según el valor del prospecto.

### 3.4 Asesor (`Advisor`) — opcional en Fase 1
Agente conversacional que explica coberturas, deducibles, exclusiones.
**Siempre marca como "información general, no cotización vinculante"**
y refiere al humano para emitir. En Fase 1 puedes saltarte esto y usar
tu propio tiempo; en Fase 2 lo activas para escalar.

### 3.5 Especialista por ramo (`Expert:Auto`, `Expert:GMM`, …)
Es el que Chava llama "especialista por división". En seguros es
**especialista por ramo**. Cada uno:
- Lee diariamente fuentes de su ramo (CONDUSEF, AMIS, blogs de
  aseguradoras, YouTube — ver método Apify del transcript).
- Mantiene en Supabase un digest actualizado de productos, cambios
  regulatorios, tasas, nuevas coberturas.
- Es llamado por el `Advisor` cuando una pregunta cae en su dominio.

**Empieza con UNO.** Agregas los demás cuando el primero convierte.

### 3.6 Creador de contenido (`Creator`)
- Publica diario en redes (LinkedIn, IG, TikTok).
- Formatos: explicativos de 60 s, mitos vs. realidad, "qué pasa si…".
- Fase 1: solo texto + imagen. Fase 3: video con tu avatar.
- Objetivo doble: SEO humano **y AEO** (que ChatGPT/Claude te citen
  cuando alguien pregunta "qué seguro me conviene"). Para AEO hay que
  publicar en fuentes que esos modelos rastreen (tu propio sitio con
  schema.org, Medium, Reddit, Quora).

### 3.7 Guardián del cliente (`Shepherd`) — Fase 2
Para clientes **ya emitidos**:
- Avisa de renovación 60 / 30 / 7 días antes.
- Felicita cumpleaños, aniversario de póliza.
- Detecta eventos de vida (vía redes: boda, hijo, mudanza, auto nuevo)
  y dispara cross-sell suave.
- Es el que *replica el truco de Chava*: "oye, vi que estás en Japón,
  ten un buen viaje" → recuérdale que el GMM internacional existe.

---

## 4. Flujo end-to-end (ejemplo auto)

```
[Anuncio Meta / Google / orgánico]
        ↓
[Landing page con formulario corto]
        ↓
[Webhook → Scout]  ← enriquecimiento en 20 s
        ↓
[Router evalúa: ¿horario? ¿calidad? ¿canal preferente?]
        ↓
[Greeter manda WhatsApp]  (o llama si opt-in)
        ↓
     ¿contesta?
     ├── Sí → qualifica dolor → agenda llamada
     └── No → secuencia nurture (3 toques en 7 días)
        ↓
[Llamada: humano o Advisor según valor]
        ↓
[Cotización emitida por humano con cédula]
        ↓
[Shepherd toma al cliente] → renovaciones y cross-sell
```

Todo esto registrado en el CRM (que, siguiendo el consejo de Chava, es
código tuyo generado con Claude, no una suscripción externa — pero
honestamente, para empezar **HubSpot gratis** o **Attio** te resuelve en
una tarde y luego migras).

---

## 5. Plan de trabajo por fases

### Fase 0 — Preparación (semana 1)
- [ ] Elegir ramo inicial y perfil de cliente ideal (1 página escrita).
- [ ] Dar de alta: Supabase, OpenRouter, GitHub, Railway, Apify, Twilio.
- [ ] Si no la tienes: tramitar cédula de agente ante CNSF (o equivalente),
      o firmar convenio con un broker/MGA que te permita operar bajo su
      figura. **Sin esto nada vende.**
- [ ] Comprar dominio + hosting del landing.

### Fase 1 — MVP operable (semanas 2–5)
- [ ] Esquema de Supabase: `leads`, `interactions`, `knowledge`,
      `clients`, `policies`.
- [ ] Router + Scout + Greeter + 1 Expert (del ramo elegido).
- [ ] Landing page con formulario → webhook.
- [ ] Integración WhatsApp Business.
- [ ] Flujo de agenda (Cal.com, gratis).
- [ ] CRM mínimo (HubSpot free o uno propio en Supabase).
- [ ] Ambiente staging + production separados.
- **Meta de la fase:** 10 leads reales procesados, 3 cotizaciones
  emitidas por el humano, 1 póliza cerrada.

### Fase 2 — Contenido y presencia (semanas 6–9)
- [ ] Creator posteando 1×/día en 2 redes.
- [ ] 20 artículos SEO/AEO en el sitio (lo producen Expert + Creator).
- [ ] Advisor activado para conversaciones calificadas.
- [ ] Shepherd corriendo sobre los primeros clientes.
- **Meta:** 50 leads/mes orgánicos + 20 pagados, 5 pólizas/mes.

### Fase 3 — Avatar y voz (semanas 10–13)
- [ ] Clonar tu voz (ElevenLabs).
- [ ] Avatar en video (HeyGen) para contenido corto.
- [ ] Opción de llamada por voz con `Greeter` (no obligatoria,
      canal secundario — el principal sigue siendo WhatsApp).
- [ ] Segundo Expert (segundo ramo).
- **Meta:** 15 pólizas/mes, LTV calculado y accionable.

### Fase 4 — Aprendizaje y escala (mes 4 en adelante)
- [ ] Hermes-style feedback loop: cada interacción se puntúa, los
      agentes se re-entrenan con los ejemplos ganadores.
- [ ] Tercer y cuarto Expert.
- [ ] Dashboard de KPIs: CPL, CPQ, CPA, close rate, LTV, retención.
- [ ] Variantes del avatar para distintos segmentos (joven vs. adulto
      mayor; particular vs. empresa) — el truco de Chava de los
      "personajes".

---

## 6. KPIs mínimos a instrumentar desde Fase 1

- **Tiempo registro → primer contacto** (meta: <2 min en horario, <10 min
  cola fuera de horario).
- **Tasa de respuesta WhatsApp** (meta: >40%).
- **Tasa de calificación** (leads que pasan a cotización / total).
- **Costo por lead y por póliza** (CPL, CPA).
- **Close rate del humano** por fuente.
- **Costo IA diario** (que el CFO del router corte si supera presupuesto).
- **NPS post-emisión** y renovación año 1.

---

## 7. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| CNSF o aseguradora detecta que un bot "asesora" | Guardrails en el prompt + disclaimer en cada mensaje + humano con cédula en el cierre. |
| Alucinación del Advisor sobre coberturas | Retrieval obligado desde Supabase, no se permite respuesta sin cita. Logs auditables. |
| Fuga de datos personales (PII) | Supabase con RLS, cifrado en reposo, nada de PII a modelos externos sin anonimizar. |
| Dependencia de un solo proveedor LLM | OpenRouter como abstracción — exactamente el argumento "agnóstico" de Chava. |
| Reputación por mensaje a horas inadecuadas | Scheduler con zona horaria del lead + ventana de contacto configurable. |
| Que te quemes manteniéndolo solo | Documenta todo en el repo + un agente `Scribe` que escriba el manual mientras se construye (ver siguiente punto). |

---

## 8. El agente `Scribe` (el consejo bueno que sí roba al transcript)

La idea de "mientras lo construyes, que se escriba el manual" es oro
para un operador solo. `Scribe`, un octavo agente ligero, observa commits de GitHub, cambios de prompts, nuevas tablas
en Supabase, y mantiene actualizado un `OPERATIONS.md` con "cómo está
armado esto hoy". Si te atropella un camión mañana, quien tome tu laptop
puede continuar leyendo ese archivo.

---

## 9. Qué construir **esta semana** (si empiezas hoy)

1. Escribe en una hoja: **ramo, segmento, propuesta de valor en 1 frase**.
2. Da de alta Supabase y crea las 5 tablas base.
3. Clona este repo, agrega un `src/` con Pydantic AI y un primer agente
   `scout.py` que recibe un JSON de lead y devuelve un brief.
4. Compra el dominio y arma un landing de una sola página con formulario.
5. Deja el acceso a OpenRouter listo con límite de gasto diario.

Con eso ya puedes procesar el primer lead real. El resto crece encima.

---

## 10. Lo que NO voy a copiar del transcript (y por qué)

- **No** 15 agentes el día 1. Un sistema de 15 agentes que una sola
  persona mantiene es un sistema que en 3 meses nadie entiende, ni tú.
- **No** avatar en Fase 1. Grabas la cara real tuya en 10 videos cortos
  y conviertes mejor que cualquier clon mientras no tengas volumen.
- **No** WhiteLabel contratado a un tercero. Chava le vende a Jorge un
  white label porque Jorge tiene presupuesto y prisa; tú tienes tiempo
  y necesitas entender cada pieza. Constrúyelo tú (con Claude Code al
  lado) — en 10 semanas lo tienes, en el camino aprendes el negocio.
- **No** llamada automatizada por voz como canal principal. En seguros
  en LATAM, WhatsApp convierte más y asusta menos. Voz es Fase 3.
