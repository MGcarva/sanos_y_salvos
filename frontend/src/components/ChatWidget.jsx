import { useState, useEffect, useRef } from 'react'

/**
 * ChatWidget — Asistente "Amigo" de Sanos y Salvos.
 *
 * Arquitectura de red (importante entender):
 * - Este componente corre en el NAVEGADOR del usuario.
 * - El navegador accede a n8n a través del puerto 5678 expuesto
 *   en la máquina local (localhost:5678).
 * - n8n, internamente, llama al BFF usando el nombre del servicio
 *   Docker (bff-service:8080). Eso ocurre dentro de la red Docker,
 *   no en el navegador. Por eso aquí usamos localhost:5678 y no
 *   bff-service.
 */

// URL del webhook de n8n. El navegador la llama directamente.
// En local con Docker: n8n escucha en el puerto 5678 de tu máquina.
const N8N_WEBHOOK_URL = 'http://localhost:5678/webhook/sanos-chat';

/**
 * Genera o recupera el ID de sesión del usuario.
 * Se guarda en sessionStorage para que persista mientras la pestaña
 * esté abierta, pero se reinicie si el usuario abre una pestaña nueva.
 * Esto sincroniza exactamente con la memoria del agente en n8n.
 */
function getSessionId() {
  let id = sessionStorage.getItem('sanos_chat_session');
  if (!id) {
    id = 'user_' + Date.now() + '_' + Math.random().toString(36).substr(2, 8);
    sessionStorage.setItem('sanos_chat_session', id);
  }
  return id;
}

// Mensaje de bienvenida que aparece cuando el usuario abre el chat
// por primera vez, antes de escribir nada.
const WELCOME_MESSAGE = {
  from: 'bot',
  text: '¡Guau! 🐾 Hola, soy Amigo, tu asistente en Sanos y Salvos. Estoy aquí para ayudarte a encontrar mascotas perdidas o reportar una que hayas encontrado. ¿En qué te puedo ayudar hoy?',
};

export default function ChatWidget() {
  const [open, setOpen]       = useState(false);
  const [messages, setMessages] = useState([WELCOME_MESSAGE]);
  const [input, setInput]     = useState('');
  const [loading, setLoading] = useState(false);

  // El sessionId se genera una vez y no cambia durante la sesión
  const sessionId = useRef(getSessionId());

  // Referencia al final de la lista de mensajes para hacer scroll automático
  const messagesEndRef = useRef(null);

  // Referencia al input de texto para poner el foco cuando se abre el chat
  const inputRef = useRef(null);

  // Cada vez que llega un mensaje nuevo, hace scroll al final del chat
  useEffect(() => {
    if (open) {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages, open]);

  // Cuando el usuario abre el panel, pone el cursor en el input
  useEffect(() => {
    if (open) {
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  }, [open]);

  /**
   * Envía el mensaje del usuario al webhook de n8n.
   * El flujo es:
   * 1. Agrega el mensaje del usuario a la UI inmediatamente.
   * 2. Hace POST al webhook con { sessionId, message }.
   * 3. n8n procesa la consulta con Claude y las tools.
   * 4. Agrega la respuesta del agente a la UI.
   */
  async function sendMessage() {
    const text = input.trim();
    if (!text || loading) return;

    // Muestra el mensaje del usuario de inmediato para que se vea fluido
    setMessages(prev => [...prev, { from: 'user', text }]);
    setInput('');
    setLoading(true);

    try {
      const response = await fetch(N8N_WEBHOOK_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sessionId: sessionId.current,
          message: text,
        }),
      });

      if (!response.ok) {
        throw new Error('Error al comunicarse con el servidor');
      }

      const data = await response.json();
      const reply = data.reply || data.output || data.response || 
                    'No pude procesar tu consulta. Intenta de nuevo.';

      setMessages(prev => [...prev, { from: 'bot', text: reply }]);
    } catch (err) {
      console.error('Error en chat:', err);
      setMessages(prev => [...prev, { 
        from: 'bot', 
        text: '🐾 ¡Guau! Parece que tengo problemas para conectarme. Por favor, verifica que n8n esté corriendo en http://localhost:5678 e intenta de nuevo.' 
      }]);
    } finally {
      setLoading(false);
    }
  }

  // Enter envía el mensaje. Shift+Enter inserta un salto de línea.
  function handleKeyDown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  }

  return (
    <>
      {/* ── Panel de chat (visible solo cuando open === true) ── */}
      {open && (
        <div
          style={{
            position: 'fixed',
            bottom: '90px',
            right: '24px',
            width: '360px',
            maxHeight: '520px',
            display: 'flex',
            flexDirection: 'column',
            backgroundColor: '#ffffff',
            borderRadius: '16px',
            boxShadow: '0 8px 32px rgba(0,0,0,0.18)',
            zIndex: 9999,
            overflow: 'hidden',
            border: '1px solid #e8ecf1',
            // Usa la misma fuente que el resto de Sanos y Salvos
            fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, sans-serif',
          }}
        >
          {/* Cabecera con gradiente igual al de la app */}
          <div
            style={{
              background: 'linear-gradient(135deg, #4361ee 0%, #3a0ca3 100%)',
              color: '#fff',
              padding: '14px 18px',
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              flexShrink: 0,
            }}
          >
            <span style={{ fontSize: '28px' }}>🐾</span>
            <div>
              <div style={{ fontWeight: '700', fontSize: '15px' }}>Amigo</div>
              <div style={{ fontSize: '11px', opacity: 0.85 }}>
                Asistente de Sanos y Salvos
              </div>
            </div>
            <button
              onClick={() => setOpen(false)}
              style={{
                marginLeft: 'auto',
                background: 'rgba(255,255,255,0.2)',
                border: 'none',
                borderRadius: '50%',
                width: '28px',
                height: '28px',
                color: '#fff',
                cursor: 'pointer',
                fontSize: '14px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
              aria-label="Cerrar chat"
            >
              ✕
            </button>
          </div>

          {/* Lista de mensajes */}
          <div
            style={{
              flex: 1,
              overflowY: 'auto',
              padding: '14px',
              display: 'flex',
              flexDirection: 'column',
              gap: '10px',
              backgroundColor: '#f8f9fa',
            }}
          >
            {messages.map((msg, idx) => (
              <div
                key={idx}
                style={{
                  display: 'flex',
                  justifyContent: msg.from === 'user' ? 'flex-end' : 'flex-start',
                }}
              >
                <div
                  style={{
                    maxWidth: '82%',
                    padding: '9px 13px',
                    // Las burbujas del usuario tienen esquina inferior derecha plana
                    // y las del bot tienen esquina inferior izquierda plana,
                    // igual que WhatsApp y otros chats familiares.
                    borderRadius: msg.from === 'user'
                      ? '16px 16px 4px 16px'
                      : '16px 16px 16px 4px',
                    backgroundColor: msg.from === 'user' ? '#4361ee' : '#ffffff',
                    color: msg.from === 'user' ? '#fff' : '#2d3436',
                    fontSize: '13.5px',
                    lineHeight: '1.5',
                    boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
                    // pre-wrap respeta los saltos de línea que devuelve el agente
                    whiteSpace: 'pre-wrap',
                    wordBreak: 'break-word',
                  }}
                >
                  {msg.text}
                </div>
              </div>
            ))}

            {/* Indicador de "Amigo está escribiendo..." mientras n8n procesa */}
            {loading && (
              <div style={{ display: 'flex', justifyContent: 'flex-start' }}>
                <div
                  style={{
                    padding: '9px 16px',
                    borderRadius: '16px 16px 16px 4px',
                    backgroundColor: '#ffffff',
                    boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
                    fontSize: '18px',
                    color: '#4361ee',
                    letterSpacing: '3px',
                  }}
                >
                  ●●●
                </div>
              </div>
            )}

            {/* Div invisible al que hacemos scroll para ver el último mensaje */}
            <div ref={messagesEndRef} />
          </div>

          {/* Área de escritura */}
          <div
            style={{
              padding: '12px 14px',
              borderTop: '1px solid #e8ecf1',
              display: 'flex',
              gap: '8px',
              backgroundColor: '#fff',
              flexShrink: 0,
            }}
          >
            <textarea
              ref={inputRef}
              value={input}
              onChange={e => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Escribe tu pregunta..."
              rows={1}
              disabled={loading}
              style={{
                flex: 1,
                resize: 'none',
                border: '2px solid #e8ecf1',
                borderRadius: '10px',
                padding: '8px 12px',
                fontSize: '13.5px',
                fontFamily: 'inherit',
                outline: 'none',
                backgroundColor: loading ? '#f8f9fa' : '#fff',
                color: '#2d3436',
                lineHeight: '1.4',
                transition: 'border-color 0.2s',
              }}
              onFocus={e => (e.target.style.borderColor = '#4361ee')}
              onBlur={e => (e.target.style.borderColor = '#e8ecf1')}
            />
            <button
              onClick={sendMessage}
              disabled={loading || !input.trim()}
              style={{
                width: '40px',
                height: '40px',
                borderRadius: '10px',
                border: 'none',
                backgroundColor: loading || !input.trim() ? '#d5dbe3' : '#4361ee',
                color: '#fff',
                cursor: loading || !input.trim() ? 'not-allowed' : 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '16px',
                flexShrink: 0,
                alignSelf: 'flex-end',
                transition: 'background-color 0.2s',
              }}
              aria-label="Enviar mensaje"
            >
              ➤
            </button>
          </div>
        </div>
      )}

      {/* ── Botón flotante 🐾 en la esquina inferior derecha ── */}
      <button
        onClick={() => setOpen(prev => !prev)}
        style={{
          position: 'fixed',
          bottom: '24px',
          right: '24px',
          width: '58px',
          height: '58px',
          borderRadius: '50%',
          background: 'linear-gradient(135deg, #4361ee 0%, #3a0ca3 100%)',
          border: 'none',
          color: '#fff',
          fontSize: '26px',
          cursor: 'pointer',
          boxShadow: '0 4px 18px rgba(67, 97, 238, 0.45)',
          zIndex: 10000,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          transition: 'transform 0.2s, box-shadow 0.2s',
        }}
        onMouseEnter={e => {
          e.currentTarget.style.transform = 'scale(1.1)';
          e.currentTarget.style.boxShadow = '0 6px 24px rgba(67, 97, 238, 0.6)';
        }}
        onMouseLeave={e => {
          e.currentTarget.style.transform = 'scale(1)';
          e.currentTarget.style.boxShadow = '0 4px 18px rgba(67, 97, 238, 0.45)';
        }}
        aria-label={open ? 'Cerrar chat' : 'Abrir chat con Amigo'}
        title="Habla con Amigo 🐾"
      >
        {open ? '✕' : '🐾'}
      </button>
    </>
  );
}
