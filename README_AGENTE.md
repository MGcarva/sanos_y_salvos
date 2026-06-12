# 🐾 Agente IA "Amigo" - Inicio Rápido

## ✅ Estado Actual

El workflow del agente **ya está desplegado y funcionando en n8n**. Solo necesitas integrar el widget de chat en el frontend.

## 🚀 Para empezar ahora mismo:

### 1. Asegúrate de que n8n esté corriendo:
```powershell
docker compose -f docker-compose.yml -f docker-compose.n8n.yml up -d
```

### 2. Verifica que el workflow esté activo:
- Abre: **http://localhost:5679**
- El workflow "Sanos y Salvos - AI Agent Amigo" debe estar en estado **Active**
- El webhook debe estar disponible en: `http://localhost:5679/webhook/sanos-chat`

### 3. Inicia el frontend:
```powershell
cd frontend
npm install  # solo la primera vez
npm run dev
```

### 4. ¡Prueba el chat!
- Ve a: **http://localhost:5173**
- Haz clic en el botón 🐾 en la esquina inferior derecha
- Escribe: "Hola"

---

## 📁 Archivos integrados:

✅ **frontend/src/components/ChatWidget.jsx** - Widget de chat React  
✅ **frontend/src/App.jsx** - Integración del widget (ya modificado)  
✅ **docker-compose.n8n.yml** - Configuración Docker de n8n  
✅ **n8n-workflow-amigo.json** - Respaldo del workflow (ya está en n8n)  
✅ **GUIA_AGENTE_AMIGO.md** - Guía completa de referencia  

---

## 🎯 El agente puede:

- 🔍 Buscar mascotas perdidas/encontradas por especie, raza, color
- 📊 Mostrar estadísticas de la plataforma
- 📍 Buscar reportes cerca de una ubicación (Santiago, Providencia, etc.)
- 🔗 Ver coincidencias de reportes

---

## 🐛 Si algo no funciona:

1. Verifica que n8n esté corriendo: `docker ps | Select-String "sanos-n8n"`
2. Revisa que el workflow esté "Active" en n8n
3. Consulta **GUIA_AGENTE_AMIGO.md** para troubleshooting detallado

---

**¿Necesitas más ayuda?** Lee la guía completa en `GUIA_AGENTE_AMIGO.md`
