# Mejoras implementadas en el Agente Amigo

## Problema Original
El chatbot no encontraba mascotas en "Villa Inca" por dos razones:
1. **Villa Inca no estaba en el diccionario** hardcodeado de ubicaciones
2. **Confusión semántica**: "encontrar un gato" se interpretaba como buscar reportes tipo ENCONTRADO

## Solución Implementada

### ✅ Geocodificación en Tiempo Real
**Antes:**
- Diccionario hardcodeado con ~25 ciudades
- Sólo funcionaba con ubicaciones predefinidas
- No permitía direcciones específicas

**Ahora:**
- Usa **Nominatim (OpenStreetMap)** - API gratuita
- Funciona con CUALQUIER ubicación de Chile:
  - ✓ Barrios: "Villa Inca", "Barrio Italia"
  - ✓ Comunas: "Providencia", "Las Condes"
  - ✓ Direcciones: "Avenida Libertador 123"
  - ✓ Sectores: "Centro de Santiago"

**Ventajas:**
- Sin límites de ubicaciones
- Más preciso que el diccionario
- Gratis, sin necesidad de API key
- Actualizado con datos recientes de OpenStreetMap

### ✅ Prompt mejorado
Actualizado el system message del agente para clarificar:
- "encontrar un gato" = buscar en AMBOS tipos (PERDIDO y ENCONTRADO)
- Solo filtrar por tipo cuando el usuario diga explícitamente "perdidos" o "encontrados"

## Archivos Modificados

1. **n8n-workflow-amigo.json** - Workflow actualizado con:
   - Nuevo código de geocodificación en `Tool buscar_por_ubicacion`
   - Descripción actualizada de la herramienta
   - System prompt mejorado

2. **docker-compose.n8n.yml** - Corregida configuración:
   - `N8N_PORT` cambiado de 5679 a 5678 (puerto interno correcto)
   - Eliminado crash loop del contenedor

3. **docker-compose.yml** - Corregido health check del BFF:
   - Path cambiado de `/actuator/health` a `/api/actuator/health`

## Pruebas Recomendadas

Una vez activado el workflow en n8n, prueba estos casos:

```
Usuario: "buscar gato blanco"
Usuario: "villa inca"
Resultado esperado: Encuentra el gato blanco perdido en Villa Inca
```

```
Usuario: "mascotas cerca de Avenida Providencia 123"
Resultado esperado: Geocodifica la dirección y busca en radio de 10km
```

```
Usuario: "reportes en Barrio Italia"
Resultado esperado: Geocodifica y busca mascotas cercanas
```

## Código Nuevo de Geocodificación

Ver archivo: `nuevo-codigo-ubicacion.js`

Función principal:
```javascript
async function geocodificar(direccion) {
  // Llama a Nominatim API (OpenStreetMap)
  // Retorna: { lat, lng, displayName }
  // Limitado a Chile (countrycodes=cl)
}
```

## Estado Actual del Sistema

✅ Todos los servicios funcionando:
- postgres (healthy)
- redis (healthy)  
- rabbitmq (healthy)
- minio (healthy)
- auth-service (healthy)
- ms-mascotas (healthy)
- ms-geolocalizacion (healthy)
- ms-coincidencias (healthy)
- bff-service (healthy)
- n8n (running)

⏳ Pendiente:
- Importar workflow actualizado en n8n
- Activar workflow
- Probar con "villa inca"

## Credenciales Necesarias

Para que el agente funcione, n8n necesita:
- **API Key de Anthropic** (para usar Claude Sonnet 4)

Si no tienes una, puedes:
1. Crear cuenta en https://console.anthropic.com
2. Obtener $5 USD de crédito gratis
3. Generar API key

## Próximos Pasos

1. Importar `n8n-workflow-amigo.json` en n8n
2. Configurar credencial de Anthropic
3. Activar workflow
4. Probar búsqueda con "villa inca"
5. (Opcional) Verificar endpoint `/api/geo/nearby` en BFF
