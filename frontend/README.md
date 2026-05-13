# Sanos y Salvos — Frontend

Aplicación web React para la plataforma de mascotas perdidas y encontradas **Sanos y Salvos**. Permite a los usuarios publicar reportes, visualizar un mapa interactivo con los avistamientos y consultar coincidencias de mascotas.

## Tecnologías

| Herramienta | Versión | Rol |
|------------|---------|-----|
| React | 18.3.1 | Framework UI |
| Vite | 5.3.1 | Bundler/Dev Server |
| React Router DOM | 6.23.1 | Enrutamiento SPA |
| Leaflet / React-Leaflet | 1.9.4 / 4.2.1 | Mapa interactivo |
| Axios | 1.7.2 | Cliente HTTP |
| Bootstrap | 5.3.3 | Estilos y componentes |
| Vitest | 1.6.0 | Test runner |
| @testing-library/react | 15.x | Testing de componentes |

## Estructura de carpetas

```
frontend/
├── src/
│   ├── components/       # Componentes reutilizables
│   │   ├── Navbar.jsx
│   │   ├── Footer.jsx
│   │   ├── ReporteMap.jsx
│   │   └── PrivateRoute.jsx
│   ├── contexts/         # Estado global (Context API)
│   │   └── AuthContext.jsx
│   ├── pages/            # Vistas/rutas
│   │   ├── Home.jsx
│   │   ├── Login.jsx
│   │   ├── Register.jsx
│   │   ├── VerifyEmail.jsx
│   │   ├── Reportar.jsx
│   │   ├── MisReportes.jsx
│   │   ├── ReporteDetalle.jsx
│   │   ├── Mapa.jsx
│   │   └── NotFound.jsx
│   ├── services/         # Lógica de negocio y HTTP
│   │   ├── api.js
│   │   └── services.js
│   ├── App.jsx
│   └── main.jsx
├── package.json
├── vite.config.js
└── Dockerfile
```

## Requisitos previos

- Node.js >= 18
- npm >= 9
- BFF-Service corriendo en `http://localhost:8080` (o configurar `VITE_API_URL`)

## Instalación y ejecución en local

```bash
# 1. Instalar dependencias
npm install

# 2. Iniciar servidor de desarrollo
npm run dev
```

El servidor queda disponible en `http://localhost:5173`.

### Variables de entorno

Crea un archivo `.env` en la raíz del frontend:

```env
VITE_API_URL=http://localhost:8080
```

## Compilar para producción

```bash
npm run build
```

Los archivos se generan en `dist/`. Se sirven estáticamente mediante nginx (ver `nginx.conf`).

## Ejecutar pruebas unitarias

```bash
# Correr tests una vez
npm test

# Modo watch (recarga al guardar)
npm run test:watch

# Reporte de cobertura
npm run test:coverage
```

Los tests usan **Vitest** + **@testing-library/react** + **jsdom**.

## Patrones de diseño aplicados

### Context Pattern (Contexto de autenticación)
`AuthContext.jsx` provee el estado de sesión globalmente mediante React Context, evitando prop drilling. Todos los componentes que necesitan saber si hay un usuario autenticado consumen este contexto.

### Proxy Pattern (capa de servicios)
`services.js` y `api.js` abstraen todas las llamadas HTTP. Los componentes no llaman directamente a `fetch/axios`; en su lugar consumen funciones del servicio, lo que facilita el cambio de URL o la adición de lógica de caché sin tocar los componentes.

### Protected Route Pattern
`PrivateRoute.jsx` implementa el patrón de rutas protegidas: redirige al login si no hay sesión activa, centralizando la lógica de autorización en un único lugar.

## Docker

```bash
# Construir imagen
docker build -t sanos-y-salvos-frontend .

# Ejecutar contenedor
docker run -p 80:80 sanos-y-salvos-frontend
```
