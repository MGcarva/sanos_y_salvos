# 🐾 Guía de Configuración - Agente IA "Amigo"

## ✅ Estado Actual

El workflow del agente **ya está desplegado y funcionando en tu instancia de n8n**. Esta guía te ayudará a:
- Verificar que todo esté configurado correctamente
- Integrar el widget de chat en el frontend
- Solucionar problemas comunes

## Descripción General

**Amigo** es un asistente virtual con inteligencia artificial que ayuda a los usuarios de Sanos y Salvos a:
- Buscar mascotas perdidas o encontradas
- Ver estadísticas de la plataforma
- Encontrar reportes cercanos a una ubicación
- Verificar coincidencias de reportes

El agente está implementado con:
- **n8n**: Plataforma de automatización para el flujo de trabajo
- **Claude Sonnet 4**: Modelo de lenguaje de Anthropic
- **React**: Widget de chat integrado en el frontend

---

## 📋 Requisitos Previos

### 1. API Key de Anthropic

Necesitas una clave API de Anthropic para usar Claude:

1. Ve a [https://console.anthropic.com](https://console.anthropic.com)
2. Crea una cuenta o inicia sesión
3. Ve a la sección "API Keys"
4. Genera una nueva API Key
5. **Guarda la clave** (la necesitarás en el paso de configuración)

### 2. Docker y Docker Compose

Asegúrate de tener instalado:
- Docker Desktop para Windows
- Docker Compose (incluido con Docker Desktop)

---

## 🚀 Verificación Rápida

### ✅ Checklist de Configuración Actual

1. **n8n está corriendo**: 
   ```powershell
   docker ps | Select-String "sanos-n8n"
   # Debe mostrar el contenedor sanos-n8n
   ```

2. **El workflow está activo**:
   - Ve a http://localhost:5679
   - Debes ver "Sanos y Salvos - AI Agent Amigo" en estado **Active**

3. **El webhook responde**:
   ```powershell
   $body = @{ sessionId = "test"; message = "Hola" } | ConvertTo-Json
   Invoke-RestMethod -Uri "http://localhost:5679/webhook/sanos-chat" -Method POST -Body $body -ContentType "application/json"
   # Debe devolver una respuesta del agente
   ```

4. **El frontend tiene el widget**:
   - Verifica que existe: `frontend/src/components/ChatWidget.jsx`
   - Verifica que App.jsx lo importa y usa

---

## 🚀 Instalación Paso a Paso (Si Necesitas Reinstalar)

### Paso 1: Levantar n8n con Docker

Desde la raíz del proyecto, ejecuta:

```powershell
docker compose -f docker-compose.yml -f docker-compose.n8n.yml up -d
```

Este comando:
- Levanta todos los servicios de Sanos y Salvos (base de datos, backend, frontend, etc.)
- Agrega n8n a la red `sanos-network` para que pueda comunicarse con el BFF

Espera unos segundos y verifica que n8n esté corriendo:
 (Solo si no existe)

**Nota**: Si ya tienes el workflow "Sanos y Salvos - AI Agent Amigo" en n8n, **sáltate este paso**.
```powershell
docker ps | Select-String "sanos-n8n"
```

### Paso 2: Acceder a n8n

1. Abre tu navegador y ve a: **http://localhost:5679**
2. La primera vez, n8n te pedirá crear un usuario:
   - **Email**: tu@email.com (puede ser cualquiera para desarrollo local)
   - **Password**: tu contraseña segura
   - **Nombre**: Tu nombre
3. Haz clic en "Get started"

### Paso 3: Configurar Credenciales de Anthropic

Antes de importar el workflow, debes configurar las credenciales:

1. En n8n, haz clic en tu avatar (esquina superior derecha)
2. Selecciona **"Settings"** → **"Credentials"**
3. Haz clic en **"+ Add Credential"**
4. Busca y selecciona **"Anthropic API"**
5. Configura:
   - **Name**: `Anthropic account`
   - **API Key**: Pega tu clave API de Anthropic
6. Haz clic en **"Save"**

### Paso 4: Importar el Workflow

1. En n8n, haz clic en el botón **"+"** (esquina superior izquierda)
2. Selecciona **"Import from File"**
3. Busca y selecciona el archivo: `n8n-workflow-amigo.json` (en la raíz del proyecto)
4. El workflow aparecerá con todos los nodos configurados

### Paso 5: Vincular las Credenciales

1. En el canvas del workflow, haz clic en el nodo **"Anthropic Claude Sonnet"**
2. En el panel derecho, busca la sección **"Credential to connect with"**
3. Selecciona la credencial que creaste en el Paso 3: `Anthropic account`
4. Haz clic en **"Save"** en la esquina superior derecha del workflow

### Paso 6: Activar el Workflow

1. En la esquina superior derecha, verás un toggle **"Inactive"**
2. Haz clic para cambiar a **"Active"**
3. El workflow ahora está escuchando en: `http://localhost:5679/webhook/sanos-chat`

### Paso 7: Probar el Chat en el Frontend

1. Asegúrate de que el frontend esté corriendo:
   ```powershell
   cd frontend
   npm run dev
   ```

2. Abre el navegador en: **http://localhost:5173**

3. Verás un botón flotante con el emoji 🐾 en la esquina inferior derecha

4. Haz clic en el botón para abrir el chat

5. Prueba con mensajes como:
   - "Hola" (para ver el saludo)
   - "¿Cuántas mascotas perdidas hay?"
   - "Busca perros golden retriever"
   - "Reportes en Santiago"

---

## 🔧 Arquitectura de Red

Es importante entender cómo se comunican los componentes:

```
┌─────────────┐
│  Navegador  │ ← Usuario visita http://localhost:5173
│  (Usuario)  │
└──────┬──────┘
       │
       │ HTTP POST a http://localhost:5679/webhook/sanos-chat
       ↓
┌─────────────────────────────────────────────────────┐
│  n8n (puerto 5679)                                  │
│  ┌─────────────────────────────────────────┐       │
│  │ 1. Webhook recibe mensaje del usuario   │       │
│  │ 2. Extrae sessionId y mensaje           │       │
│  │ 3. Llama al agente IA con Claude        │       │
│  │ 4. Claude decide qué herramienta usar   │       │
│  └─────────────────┬───────────────────────┘       │
│                    │                                │
│                    │ Dentro de Docker:              │
│                    │ http://bff-service:8080        │
│                    ↓                                │
│  ┌──────────────────────────────────────┐          │
│  │ Tools (buscar_reportes, etc.)        │          │
│  │ - Llaman al BFF usando hostname      │          │
│  │   interno de Docker                  │──────────┼──→ BFF Service
│  │ - Obtienen datos reales              │          │    (puerto 8080)
│  └──────────────────────────────────────┘          │
└─────────────────────────────────────────────────────┘
```

**Puntos clave:**
- El navegador llama a `localhost:5679` porque accede desde fuera de Docker
- n8n llama a `bff-service:8080` porque está dentro de la red Docker
- Ambos servicios están en `sanos-network`, por eso se ven entre sí

---

## 🛠️ Herramientas del Agente

El agente "Amigo" tiene 4 herramientas que usa automáticamente según la consulta:

### 1. `buscar_reportes`
- **Cuándo se usa**: El usuario pregunta por mascotas con características específicas
- **Ejemplos**: 
  - "Busca gatos blancos"
  - "Perros perdidos en la plataforma"
  - "¿Hay algún golden retriever reportado?"
- **Endpoint**: `GET /api/reportes`

### 2. `ver_estadisticas`
- **Cuándo se usa**: El usuario pide números o resumen general
- **Ejemplos**: 
  - "¿Cuántas mascotas hay perdidas?"
  - "Dame las estadísticas"
  - "¿Cuántos reportes hay?"
- **Endpoint**: `GET /api/dashboard`

### 3. `buscar_por_ubicacion`
- **Cuándo se usa**: El usuario menciona un lugar geográfico
- **Ejemplos**: 
  - "Reportes en Santiago"
  - "Mascotas perdidas cerca de Providencia"
  - "¿Hay algo en Melipilla?"
- **Endpoint**: `GET /api/geo/nearby?lat=X&lng=Y&radiusMeters=10000`
- **Radio**: 10km desde la ubicación

### 4. `buscar_coincidencias`
- **Cuándo se usa**: El usuario tiene un ID de reporte y quiere ver matches
- **Ejemplos**: 
  - "Coincidencias del reporte abc-123"
  - "¿Hay matches para mi reporte?"
- **Endpoint**: `GET /api/coincidencias/perdido/{id}` o `/encontrado/{id}`

---

## 🎨 Personalización del Chat

### Modificar el Mensaje de Bienvenida

Edita `frontend/src/components/ChatWidget.jsx`:

```javascript
const WELCOME_MESSAGE = {
  from: 'bot',
  text: 'Tu mensaje personalizado aquí 🐾',
};
```

### Cambiar el Color del Botón

En `ChatWidget.jsx`, busca:

```javascript
background: 'linear-gradient(135deg, #4361ee 0%, #3a0ca3 100%)',
```

Y cámbialo por tus colores preferidos.

### Modificar el Comportamiento del Agente

Para cambiar cómo responde el agente:

1. En n8n, abre el workflow
2. Haz clic en el nodo **"AI Agent"**
3. Edita el **"System Message"** en el panel derecho
4. Modifica las instrucciones según tus necesidades
5. Guarda el workflow

---

## 🐛 Solución de Problemas

### El botón 🐾 no aparece

1. Verifica que el frontend esté corriendo
2. Revisa la consola del navegador (F12) en busca de errores
3. Asegúrate de que `ChatWidget` esté importado en `App.jsx`

### El chat no responde

1. Verifica que n8n esté corriendo:
   ```powershell
   docker ps | Select-String "sanos-n8n"
   ```

2. Verifica que el workflow esté **Activo** en n8n

3. Prueba el webhook directamente con PowerShell:
   ```powershell
   $body = @{
       sessionId = "test-123"
       message = "Hola"
   } | ConvertTo-Json
   
   Invoke-RestMethod -Uri "http://localhost:5679/webhook/sanos-chat" `
                     -Method POST `
                     -Body $body `
                     -ContentType "application/json"
   ```

4. Revisa los logs de n8n:
   ```powershell
   docker logs sanos-n8n
   ```

### Error: "No pude conectarme al sistema"

Esto significa que n8n no puede alcanzar el BFF. Verifica:

1. Que todos los servicios estén corriendo:
   ```powershell
   docker compose ps
   ```

2. Que `bff-service` esté saludable:
   ```powershell
   docker ps | Select-String "bff-service"
   ```

3. Que n8n esté en la red correcta:
   ```powershell
   docker network inspect sanos-network
   ```

### Las credenciales de Anthropic fallan

1. Verifica que la API Key sea válida
2. Comprueba que tengas créditos en tu cuenta de Anthropic
3. Re-crea la credencial en n8n si es necesario

---

## 📊 Monitoreo

### Ver Ejecuciones del Workflow

1. En n8n, haz clic en **"Executions"** (en el menú lateral)
2. Verás todas las conversaciones con:
   - Timestamp
   - Estado (Success/Error)
   - Duración
3. Haz clic en una ejecución para ver el flujo completo y datos

### Ver Logs de n8n

```powershell
docker logs -f sanos-n8n
```

### Depurar Tools en Tiempo Real

1. En n8n, desactiva el workflow (toggle a "Inactive")
2. Haz clic en **"Execute Workflow"** (en la parte inferior)
3. En el nodo "Extraer Input", configura datos de prueba manualmente
4. Haz clic en "Execute Node"
5. Observa los resultados en cada nodo

---

## 🔐 Consideraciones de Seguridad

### Para Producción

Si vas a desplegar esto en producción:

1. **Activa autenticación en n8n**:
   - Edita `docker-compose.n8n.yml`
   - Cambia `N8N_BASIC_AUTH_ACTIVE=true`
   - Agrega `N8N_BASIC_AUTH_USER` y `N8N_BASIC_AUTH_PASSWORD`

2. **Protege las API Keys**:
   - Usa variables de entorno
   - No subas credenciales al repositorio

3. **Restringe CORS**:
   - En el nodo "Webhook Chat", cambia:
     ```
     allowedOrigins: "https://tu-dominio.com"
     ```

4. **Limita rate limiting**:
   - Considera agregar limitación de peticiones por sesión
   - Implementa detección de spam

5. **HTTPS**:
   - Configura SSL/TLS para n8n
   - Usa un proxy reverso (Nginx)

---

## 🎯 Próximos Pasos

Una vez que tengas todo funcionando, puedes:

1. **Agregar más herramientas**:
   - Crear un reporte
   - Actualizar perfil de usuario
   - Programar notificaciones

2. **Mejorar la memoria**:
   - Usar una base de datos para memoria persistente
   - Implementar resumen de conversaciones largas

3. **Analytics**:
   - Registrar las consultas más comunes
   - Medir satisfacción del usuario
   - Optimizar las respuestas basándote en uso real

4. **Multilenguaje**:
   - Detectar el idioma del usuario
   - Responder en inglés, español, etc.

---

## 📞 Soporte

Si tienes problemas:

1. Revisa la sección de **Solución de Problemas** arriba
2. Consulta los logs de Docker y n8n
3. Verifica que todos los servicios estén en estado "healthy"
4. Revisa la documentación oficial de n8n: [https://docs.n8n.io](https://docs.n8n.io)

---

## 📝 Resumen de Archivos Creados/Modificados

- ✅ `frontend/src/components/ChatWidget.jsx` - Componente de chat
- ✅ `frontend/src/App.jsx` - Integración del ChatWidget
- ✅ `docker-compose.n8n.yml` - Configuración Docker para n8n
- ✅ `n8n-workflow-amigo.json` - Workflow completo del agente
- ✅ `GUIA_AGENTE_AMIGO.md` - Esta guía

---

¡Listo! 🎉 Ahora tienes un agente IA completamente funcional en Sanos y Salvos.
