-- Esquema multi-vertical para Supabase (Postgres + pgvector).
-- Toda tabla de negocio lleva vertical_id: un motor, varios verticales, datos aislados.

create extension if not exists vector;

create table verticales (
  id                        text primary key,  -- igual a la carpeta verticales/<id>/
  nombre                    text not null,
  estado                    text not null default 'borrador'
                              check (estado in ('borrador', 'piloto', 'activa')),
  presupuesto_ia_diario_usd numeric(8, 2) not null default 3,
  creado_en                 timestamptz not null default now()
);

create table leads (
  id                   uuid primary key default gen_random_uuid(),
  vertical_id          text not null references verticales (id),
  nombre               text,
  telefono             text,
  email                text,
  pais                 text,
  zona_horaria         text,
  ip_registro          inet,
  fuente               text,          -- meta_ads, organico, referido, ...
  datos_formulario     jsonb not null default '{}',
  respuestas           jsonb not null default '{}',  -- calificacion.preguntas del vertical
  brief                text,          -- lo escribe Scout
  puntaje              int check (puntaje between 0 and 100),
  estado               text not null default 'nuevo'
                         check (estado in ('nuevo', 'contactado', 'calificado', 'agendado',
                                           'cerrado', 'redirigido', 'descartado', 'perdido')),
  intentos             int not null default 0,
  proximo_contacto_en  timestamptz,   -- cola para leads que llegan fuera de la ventana horaria
  consentimientos      jsonb not null default '{}',
  creado_en            timestamptz not null default now()
);
create index on leads (vertical_id, estado);
create index on leads (proximo_contacto_en) where proximo_contacto_en is not null;

create table clientes (
  id                uuid primary key default gen_random_uuid(),
  vertical_id       text not null references verticales (id),
  lead_id           uuid references leads (id),
  nombre            text not null,
  telefono          text,
  email             text,
  fecha_nacimiento  date,
  consentimientos   jsonb not null default '{}',
  notas             jsonb not null default '{}',
  creado_en         timestamptz not null default now()
);
create index on clientes (vertical_id);

-- Lo que se cerró: póliza, cuenta de trading o inscripción.
create table contratos (
  id                  uuid primary key default gen_random_uuid(),
  vertical_id         text not null references verticales (id),
  cliente_id          uuid not null references clientes (id) on delete cascade,
  tipo                text not null,  -- poliza_auto, cuenta_trading, inscripcion_bachillerato, ...
  referencia_externa  text,           -- número de póliza, de cuenta o matrícula
  inicio              date not null,
  vencimiento         date,           -- renovación o fin de periodo; lo vigila Shepherd
  monto               numeric(12, 2),
  moneda              text not null default 'MXN',
  estado              text not null default 'activo'
                        check (estado in ('activo', 'vencido', 'cancelado')),
  detalles            jsonb not null default '{}',
  creado_en           timestamptz not null default now()
);
create index on contratos (vertical_id, vencimiento);

create table interacciones (
  id               uuid primary key default gen_random_uuid(),
  vertical_id      text not null references verticales (id),
  lead_id          uuid references leads (id) on delete cascade,
  cliente_id       uuid references clientes (id) on delete cascade,
  agente           text not null,   -- router, scout, greeter, advisor, shepherd, humano, ...
  canal            text not null check (canal in ('whatsapp', 'llamada', 'email', 'sms', 'interno')),
  direccion        text not null check (direccion in ('entrante', 'saliente', 'interno')),
  contenido        text,
  resultado        text,
  guardrail_regla  text,            -- regla de cumplimiento.nunca_decir que bloqueó el mensaje
  calificacion     int check (calificacion between 1 and 5),  -- feedback loop de la Fase 4
  modelo_llm       text,
  costo_usd        numeric(10, 5) not null default 0,
  creado_en        timestamptz not null default now(),
  check (lead_id is not null or cliente_id is not null)
);
create index on interacciones (vertical_id, creado_en);
create index on interacciones (lead_id);
create index on interacciones (cliente_id);

create table conocimiento (
  id            uuid primary key default gen_random_uuid(),
  vertical_id   text not null references verticales (id),
  fuente        text not null,
  fuente_url    text,
  titulo        text,
  contenido     text not null,
  embedding     vector(1536),  -- ajustar a la dimensión del modelo de embeddings elegido
  vigente_hasta date,
  creado_en     timestamptz not null default now()
);
create index on conocimiento (vertical_id);
create index on conocimiento using hnsw (embedding vector_cosine_ops);

-- El Router compara esto contra verticales.presupuesto_ia_diario_usd.
create view gasto_ia_diario with (security_invoker = true) as
select vertical_id,
       date_trunc('day', creado_en) as dia,
       sum(costo_usd)               as costo_usd
from interacciones
group by vertical_id, date_trunc('day', creado_en);

-- RLS sin políticas: solo el backend (service_role) lee y escribe. Nada expuesto al cliente anónimo.
alter table verticales    enable row level security;
alter table leads         enable row level security;
alter table clientes      enable row level security;
alter table contratos     enable row level security;
alter table interacciones enable row level security;
alter table conocimiento  enable row level security;

insert into verticales (id, nombre) values
  ('seguros', 'Seguros'),
  ('trading', 'Trading'),
  ('preparatoria-croc', 'Preparatoria CROC')
on conflict (id) do nothing;
