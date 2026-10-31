# Presentación

Presentación hecha con [Reveal.js](https://revealjs.com/) y desplegada automáticamente a GitHub Pages.

## Flujo de trabajo automatizado

- **Push a `main`** → el workflow `.github/workflows/deploy.yml` publica la presentación a GitHub Pages.
- **Pull request a `main`** → el workflow `.github/workflows/validate.yml` valida el HTML con htmlhint.

## Desarrollo local

```bash
./serve.sh          # abre http://localhost:8000
./serve.sh 3000     # usa otro puerto
```

## Estructura

```
.
├── index.html              # Las diapositivas
├── css/custom.css          # Estilos adicionales
├── serve.sh                # Servidor local
├── .htmlhintrc             # Reglas de validación
└── .github/workflows/      # Automatización (deploy + validación)
```

## Primer uso

1. Activa GitHub Pages en el repo: Settings → Pages → Source: **GitHub Actions**.
2. Haz push a `main`; el workflow desplegará y te dará la URL.
3. Edita `index.html` para añadir tus diapositivas.

## Atajos de Reveal.js

| Tecla | Acción |
|-------|--------|
| `→` / `←` | Navegar |
| `S` | Notas del presentador |
| `F` | Pantalla completa |
| `Esc` | Vista general |
| `B` | Pantalla en negro |
