# 🐾 Actualización del Agente de IA - Búsqueda Mejorada de Mascotas

## ✅ Cambios Implementados en el Backend

### 1. **Nuevo Endpoint de Búsqueda Avanzada**

Se agregó un endpoint en el microservicio `ms-mascotas` y en el BFF que permite buscar mascotas por múltiples características:

**URL:** `GET /api/reportes/buscar`

**Parámetros (todos opcionales):**
- `tipo`: PERDIDO o ENCONTRADO
- `especie`: Perro, Gato, Ave, etc.
- `raza`: Cualquier raza (búsqueda parcial)
- `color`: Color de la mascota
- `nombre`: Nombre de la mascota
- `tamano`: PEQUEÑO, MEDIANO, GRANDE

**Ejemplo:**
```
GET http://localhost:9090/api/reportes/buscar?tipo=PERDIDO&especie=Perro&color=negro
```

**Características:**
- ✅ Búsqueda case-insensitive (no diferencia mayúsculas/minúsculas)
- ✅ Búsqueda parcial (busca coincidencias dentro del texto)
- ✅ Solo devuelve reportes ACTIVOS
- ✅ Ordenado por fecha de creación (más recientes primero)
- ✅ Todos los filtros son opcionales y se pueden combinar

---

## 🔧 Actualización del Workflow de n8n

### Opción 1: Actualizar la herramienta existente en n8n (Recomendado)

1. **Abre n8n** en http://localhost:5679
2. **Busca y edita el workflow** "Sanos y Salvos - AI Agent Amigo"
3. **Localiza el nodo** "Tool buscar_reportes"
4. **Reemplaza el código JavaScript** con este nuevo:

```javascript
// HERRAMIENTA MEJORADA — Búsqueda avanzada de mascotas por características
// Usa el nuevo endpoint /api/reportes/buscar del BFF que filtra directamente en PostgreSQL
// Soporta búsqueda parcial case-insensitive para máxima flexibilidad

let filtros = {};
try {
  filtros = (typeof query !== 'undefined' && query)
    ? (typeof query === 'string' ? JSON.parse(query) : query)
    : {};
} catch(e) { 
  filtros = {}; 
}

const BFF_URL = 'http://host.docker.internal:9090';

// Construir URL con query parameters
let url = BFF_URL + '/api/reportes/buscar?';
let params = [];

// Filtro por TIPO (PERDIDO o ENCONTRADO)
if (filtros.tipo) {
  params.push('tipo=' + encodeURIComponent(filtros.tipo.toUpperCase()));
}

// Filtro por ESPECIE (Perro, Gato, Ave, etc.)
if (filtros.especie) {
  params.push('especie=' + encodeURIComponent(filtros.especie));
}

// Filtro por NOMBRE de la mascota
if (filtros.nombre) {
  params.push('nombre=' + encodeURIComponent(filtros.nombre));
}

// Filtro por RAZA
if (filtros.raza) {
  params.push('raza=' + encodeURIComponent(filtros.raza));
}

// Filtro por COLOR
if (filtros.color) {
  params.push('color=' + encodeURIComponent(filtros.color));
}

// Filtro por TAMAÑO (PEQUEÑO, MEDIANO, GRANDE)
if (filtros.tamano || filtros.tamaño) {
  const t = (filtros.tamano || filtros.tamaño).toUpperCase();
  params.push('tamano=' + encodeURIComponent(t));
}

url += params.join('&');

try {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error('BFF respondió con error ' + response.status);
  }
  
  const reportes = await response.json();

  if (!Array.isArray(reportes) || reportes.length === 0) {
    return 'No encontré mascotas con esas características. Intenta con filtros más amplios o diferentes.';
  }

  // Mostrar primeros 5 resultados
  const primeros = reportes.slice(0, 5);
  const texto = primeros.map((r, i) => {
    const tipo = r.tipo === 'PERDIDO' ? '🔴 PERDIDA' : '🟢 ENCONTRADA';
    const especie = r.especie || 'Mascota';
    const nombre = r.nombre ? ` — ${r.nombre}` : '';
    const raza = r.raza ? `, ${r.raza}` : '';
    const color = r.color ? `, color ${r.color}` : '';
    const tamano = r.tamano ? ` (${r.tamano.toLowerCase()})` : '';
    const lugar = r.direccion ? ` 📍 ${r.direccion}` : '';
    const fecha = r.fechaEvento ? ` — ${new Date(r.fechaEvento).toLocaleDateString('es-CL')}` : '';
    
    return `${i+1}. ${tipo} — ${especie}${nombre}${raza}${color}${tamano}${lugar}${fecha}`;
  }).join('\n');

  let respuesta = `Encontré ${reportes.length} mascota(s):\n${texto}`;
  
  if (reportes.length > 5) {
    respuesta += `\n\n... y ${reportes.length - 5} más. Entra a la plataforma para ver todos los resultados.`;
  }
  
  return respuesta;

} catch(err) {
  return 'No pude buscar en este momento. Error: ' + err.message;
}
```

5. **Actualiza la descripción** de la herramienta:
```
Busca reportes de mascotas en la plataforma. Acepta filtros opcionales: tipo (PERDIDO o ENCONTRADO), especie (Perro, Gato, Ave, etc.), nombre, raza, color, tamano (PEQUEÑO, MEDIANO, GRANDE). Devuelve lista de reportes activos que coincidan con las características buscadas.
```

6. **Guarda el workflow** (Ctrl+S)
7. **Activa el workflow**

---

## 🧪 Pruebas del Agente Mejorado

### Casos de prueba para el chat:

1. **Búsqueda simple por especie:**
   - "Busca perros perdidos"
   - "¿Hay gatos encontrados?"

2. **Búsqueda por características:**
   - "Busca un perro negro"
   - "Quiero encontrar un gato blanco perdido"
   - "¿Hay perros golden retriever?"

3. **Búsqueda por nombre:**
   - "Busca una mascota llamada Max"
   - "¿Han reportado a Luna?"

4. **Búsqueda combinada:**
   - "Busca perros labradores de color negro que estén perdidos"
   - "Gatos encontrados de tamaño pequeño"

5. **Búsqueda por tamaño:**
   - "Mascotas perdidas de tamaño grande"
   - "Perros pequeños encontrados"

---

## 📊 Diferencias con la versión anterior

### ❌ Antes (búsqueda en memoria):
- Descargaba TODOS los reportes
- Filtraba en JavaScript (lento e ineficiente)
- No aprovechaba índices de base de datos
- No soportaba búsqueda parcial nativa

### ✅ Ahora (búsqueda en PostgreSQL):
- Consulta directa a la base de datos
- Usa índices de PostgreSQL (rápido)
- Búsqueda case-insensitive con LIKE
- Filtrado optimizado en la base de datos
- Soporte para múltiples características combinadas

---

## 🗄️ Consulta SQL que se ejecuta en PostgreSQL

Cuando el agente busca "perro negro perdido", la consulta generada es:

```sql
SELECT r.* 
FROM reportes r 
WHERE r.estado = 'ACTIVO' 
  AND r.tipo = 'PERDIDO'
  AND LOWER(r.especie) LIKE LOWER('%perro%')
  AND LOWER(r.color) LIKE LOWER('%negro%')
ORDER BY r.created_at DESC;
```

---

## 🔍 Verificación de la implementación

### 1. Verificar que el backend se compiló correctamente:

```powershell
# Reconstruir los servicios
docker-compose up -d --build auth-service bff-service ms-mascotas
```

### 2. Probar el endpoint directamente:

```powershell
# Buscar perros perdidos
Invoke-WebRequest -Uri "http://localhost:9090/api/reportes/buscar?tipo=PERDIDO&especie=Perro"

# Buscar gatos de color negro
Invoke-WebRequest -Uri "http://localhost:9090/api/reportes/buscar?especie=Gato&color=negro"

# Buscar por nombre
Invoke-WebRequest -Uri "http://localhost:9090/api/reportes/buscar?nombre=Max"
```

### 3. Ver la documentación Swagger:

Abre http://localhost:8092/swagger-ui.html y busca el endpoint `/api/reportes/buscar`

---

## 🎯 Ejemplos de uso en el chat

### Usuario:
> "Hola, busco un perro perdido"

### Agente (Amigo):
> ¡Guau! 🐾 Déjame ayudarte. ¿Recuerdas alguna característica? (raza, color, tamaño)

### Usuario:
> "Era un labrador negro de tamaño grande"

### Agente (Amigo):
> Encontré 2 mascota(s):
> 1. 🔴 PERDIDA — Perro — Max, labrador, color negro (grande) 📍 Providencia — 04/06/2026
> 2. 🔴 PERDIDA — Perro, labrador, color negro (grande) 📍 Las Condes — 03/06/2026
>
> Entra a la plataforma para ver los detalles completos y contactar a los dueños.

---

## 🚀 Próximas mejoras sugeridas

1. **Búsqueda por similitud de imagen** usando IA
2. **Filtro por rango de fechas**
3. **Búsqueda geográfica** (mascotas cerca de mi ubicación)
4. **Alertas automáticas** cuando se reporta una mascota con características similares
5. **Integración con reconocimiento facial de mascotas**

---

## 📝 Notas técnicas

- Los cambios en el backend son **retrocompatibles** (el endpoint anterior `/api/reportes` sigue funcionando)
- La búsqueda es **eficiente** gracias a los índices en PostgreSQL
- El sistema soporta **caracteres especiales** y **tildes** en las búsquedas
- Todos los filtros son **opcionales** y se pueden **combinar** libremente
