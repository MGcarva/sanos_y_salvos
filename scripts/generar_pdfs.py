#!/usr/bin/env python3
"""Genera PDFs requeridos por la rubrica EP2 — Sanos y Salvos."""

import os
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable
)
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY

W, H = A4
MARGIN = 2.2 * cm

# Colores institucionales
AZUL       = colors.HexColor("#1565C0")
AZUL_CLARO = colors.HexColor("#E3F2FD")
GRIS       = colors.HexColor("#546E7A")
VERDE      = colors.HexColor("#2E7D32")
NEGRO      = colors.black

def estilos():
    base = dict(fontName="Helvetica", fontSize=10, leading=14,
                textColor=NEGRO, spaceAfter=6)

    def ps(name, **kw):
        d = {**base, **kw}
        return ParagraphStyle(name, **d)

    return {
        "portada_titulo": ps("portada_titulo",
            fontName="Helvetica-Bold", fontSize=26, textColor=AZUL,
            alignment=TA_CENTER, spaceAfter=12),
        "portada_sub": ps("portada_sub",
            fontName="Helvetica", fontSize=14, textColor=GRIS,
            alignment=TA_CENTER, spaceAfter=8),
        "portada_info": ps("portada_info",
            fontName="Helvetica", fontSize=11, textColor=NEGRO,
            alignment=TA_CENTER, spaceAfter=6),
        "h1": ps("h1",
            fontName="Helvetica-Bold", fontSize=16, textColor=AZUL,
            spaceBefore=18, spaceAfter=8),
        "h2": ps("h2",
            fontName="Helvetica-Bold", fontSize=13, textColor=AZUL,
            spaceBefore=12, spaceAfter=6),
        "body": ps("body", alignment=TA_JUSTIFY, leading=16),
        "code": ps("code",
            fontName="Courier", fontSize=8.5, textColor=VERDE,
            backColor=colors.HexColor("#F1F8E9"),
            leading=12, leftIndent=12, rightIndent=12,
            spaceBefore=4, spaceAfter=4),
        "bullet": ps("bullet", leftIndent=18, leading=15),
    }

E = estilos()

def portada(titulo, subtitulo, descripcion):
    items = []
    items.append(Spacer(1, 3 * cm))
    items.append(Paragraph("SANOS Y SALVOS", E["portada_titulo"]))
    items.append(HRFlowable(width="100%", thickness=2, color=AZUL))
    items.append(Spacer(1, 0.5 * cm))
    items.append(Paragraph(titulo, E["portada_sub"]))
    items.append(Spacer(1, 0.5 * cm))
    items.append(Paragraph(descripcion, E["portada_info"]))
    items.append(Spacer(1, 1 * cm))
    items.append(HRFlowable(width="60%", thickness=1, color=GRIS))
    items.append(Spacer(1, 0.5 * cm))
    items.append(Paragraph("DSY1106 - Desarrollo Fullstack III", E["portada_info"]))
    items.append(Paragraph("Evaluacion Parcial N2", E["portada_info"]))
    items.append(Paragraph("2024", E["portada_info"]))
    items.append(PageBreak())
    return items

def h1(texto):
    return [HRFlowable(width="100%", thickness=1.5, color=AZUL),
            Paragraph(texto, E["h1"])]

def h2(texto):
    return [Paragraph(texto, E["h2"])]

def body(texto):
    return [Paragraph(texto, E["body"])]

def bullet(items_list):
    return [Paragraph("- " + t, E["bullet"]) for t in items_list]

def code(texto):
    safe = texto.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    safe = safe.replace("\n", "<br/>").replace("    ", "&nbsp;&nbsp;&nbsp;&nbsp;")
    return [Paragraph(safe, E["code"]), Spacer(1, 4)]

def tabla(headers, rows, col_widths=None):
    data = [headers] + rows
    if col_widths is None:
        n = len(headers)
        col_widths = [(W - 2 * MARGIN) / n] * n
    t = Table(data, colWidths=col_widths)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), AZUL),
        ("TEXTCOLOR",  (0, 0), (-1, 0), colors.white),
        ("FONTNAME",   (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE",   (0, 0), (-1, 0), 10),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, AZUL_CLARO]),
        ("FONTNAME",   (0, 1), (-1, -1), "Helvetica"),
        ("FONTSIZE",   (0, 1), (-1, -1), 9),
        ("ALIGN",      (0, 0), (-1, -1), "LEFT"),
        ("VALIGN",     (0, 0), (-1, -1), "MIDDLE"),
        ("GRID",       (0, 0), (-1, -1), 0.5, colors.HexColor("#B0BEC5")),
        ("LEFTPADDING",  (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING",   (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 5),
    ]))
    return [t, Spacer(1, 8)]

def sp(n=1):
    return Spacer(1, n * 0.3 * cm)


# ============================================================================
# PDF 1 — PATRONES DE DISENO
# ============================================================================
def generar_patrones():
    path = "docs/PATRONES_DISENO.pdf"
    doc = SimpleDocTemplate(path, pagesize=A4,
                            leftMargin=MARGIN, rightMargin=MARGIN,
                            topMargin=MARGIN, bottomMargin=MARGIN)
    story = []

    story += portada(
        "ANALISIS DE PATRONES DE DISENO",
        "Documentacion tecnica de los patrones GoF implementados "
        "y arquetipos Maven del ecosistema de microservicios",
        "Plataforma de reporte y localizacion de mascotas perdidas"
    )

    story += h1("1. Introduccion")
    story += body(
        "El proyecto Sanos y Salvos implementa una arquitectura de microservicios "
        "compuesta por un BFF (Backend For Frontend) y cuatro microservicios especializados. "
        "Esta arquitectura exige aplicar patrones de diseno que promuevan el desacoplamiento, "
        "la extensibilidad y la mantenibilidad del sistema."
    )
    story += body(
        "En este documento se analizan seis patrones GoF implementados en el codebase, "
        "indicando el componente que los aplica, el problema que resuelven y las ventajas "
        "obtenidas. Ademas se documenta el arquetipo Maven personalizado para la generacion "
        "estandarizada de nuevos microservicios."
    )
    story += [sp(2)]

    story += h1("2. Resumen de patrones implementados")
    story += tabla(
        ["Patron", "Categoria", "Componente", "Archivo principal"],
        [
            ["Factory Method", "Creacional",    "ms-mascotas",                        "ReporteFactory.java"],
            ["Observer",       "Comportamiento","ms-mascotas / ms-geo / ms-coincidencias","EventPublisher / Listeners"],
            ["Proxy",          "Estructural",   "bff-service",                        "AuthProxyService.java"],
            ["Strategy",       "Comportamiento","ms-coincidencias / ms-geolocalizacion","ScoringService.java"],
            ["Context/Provider","Estructural",  "frontend",                           "AuthContext.jsx"],
            ["Circuit Breaker","Arquitectonico","bff-service",                        "CircuitBreakerConfig.java"],
        ],
        col_widths=[3.2*cm, 3*cm, 5.5*cm, 4.8*cm]
    )

    story += h1("3. Patron Factory Method")
    story += h2("3.1 Problema")
    story += body(
        "El microservicio ms-mascotas necesita crear dos tipos de reporte (PERDIDO / ENCONTRADO). "
        "Sin una factory, cada componente que crea reportes deberia conocer que clase concreta instanciar, "
        "acoplando la logica de negocio a los detalles de implementacion."
    )
    story += h2("3.2 Solucion - ReporteFactory")
    story += body(
        "La clase ReporteFactory centraliza la creacion. El cliente solo indica el tipo "
        "en el DTO y la factory decide que subclase instanciar:"
    )
    story += code(
        "// ms-mascotas/.../factory/ReporteFactory.java\n"
        "public Reporte crear(ReporteRequestDTO dto) {\n"
        "    return switch (dto.getTipo()) {\n"
        "        case PERDIDO    -> new ReportePerdido(dto);\n"
        "        case ENCONTRADO -> new ReporteEncontrado(dto);\n"
        "    };\n"
        "}"
    )
    story += h2("3.3 Jerarquia de clases")
    story += tabla(
        ["Clase", "Tipo", "Descripcion"],
        [
            ["Reporte",          "Abstracta", "Clase base con campos comunes (id, fecha, descripcion, foto)"],
            ["ReportePerdido",   "Concreta",  "Anade fecha de perdida y ultima ubicacion conocida"],
            ["ReporteEncontrado","Concreta",  "Anade fecha de hallazgo y ubicacion donde fue encontrada"],
            ["ReporteFactory",   "Factory",   "Decide que subclase instanciar segun dto.getTipo()"],
        ],
        col_widths=[4*cm, 3*cm, 9.5*cm]
    )
    story += h2("3.4 Ventajas")
    story += bullet([
        "Agregar un nuevo tipo de reporte solo requiere un nuevo case en la factory.",
        "ReporteService no depende de ninguna clase concreta (abierto/cerrado - OCP).",
        "Facilita el testing: se puede inyectar mocks de la factory.",
    ])
    story += [sp(2)]

    story += h1("4. Patron Observer (Event-Driven)")
    story += h2("4.1 Problema")
    story += body(
        "Al crearse un reporte en ms-mascotas, otros microservicios deben reaccionar. "
        "Si ms-mascotas llamara directamente a esos servicios crearia acoplamiento estrecho "
        "y puntos de fallo unicos que degradan la resiliencia del sistema."
    )
    story += h2("4.2 Solucion - RabbitMQ como canal de eventos")
    story += body(
        "ms-mascotas publica un ReporteNuevoEvent en RabbitMQ. Los listeners "
        "de los demas servicios reaccionan de forma completamente desacoplada:"
    )
    story += code(
        "// EventPublisher.java\n"
        "rabbitTemplate.convertAndSend(\n"
        "    \"sanos.exchange\", \"reporte.nuevo\", event\n"
        ");\n\n"
        "// GeolocalizacionListener.java\n"
        "@RabbitListener(queues = \"geo.queue\")\n"
        "public void onReporteNuevo(ReporteNuevoEvent event) { ... }"
    )
    story += h2("4.3 Flujo de eventos")
    story += tabla(
        ["Paso", "Productor", "Routing Key", "Consumidor"],
        [
            ["1", "ms-mascotas / EventPublisher",      "reporte.nuevo", "ms-geolocalizacion"],
            ["2", "ms-mascotas / EventPublisher",      "reporte.nuevo", "ms-coincidencias"],
            ["3", "ms-geolocalizacion / GeoService",   "geo.completado","ms-coincidencias"],
        ],
        col_widths=[1.5*cm, 5*cm, 3.5*cm, 6.5*cm]
    )
    story += [sp(2)]

    story += h1("5. Patron Proxy (BFF-Service)")
    story += h2("5.1 Problema")
    story += body(
        "El frontend no debe comunicarse directamente con cada microservicio. "
        "Eso expondria URLs internas, duplicaria la logica de autenticacion en el cliente "
        "y dificultaria agregar funcionalidades transversales (logging, throttling, circuit breaker)."
    )
    story += h2("5.2 Solucion - bff-service como Proxy unico")
    story += body(
        "El BFF-Service actua como proxy transparente: recibe todas las peticiones del "
        "frontend, valida el token JWT, y las redirige al microservicio correcto:"
    )
    story += code(
        "// AuthProxyService.java\n"
        "public ResponseEntity login(Map credenciales) {\n"
        "    return restTemplate.postForEntity(\n"
        "        authServiceUrl + \"/api/auth/login\",\n"
        "        credenciales, Map.class\n"
        "    );\n"
        "}"
    )
    story += h2("5.3 Rutas expuestas por el BFF (puerto 8080)")
    story += tabla(
        ["Prefijo BFF", "Microservicio destino", "Puerto interno"],
        [
            ["/api/auth/**",          "auth-service",         "8081"],
            ["/api/reportes/**",      "ms-mascotas",          "8082"],
            ["/api/geo/**",           "ms-geolocalizacion",   "8083"],
            ["/api/coincidencias/**", "ms-coincidencias",     "8084"],
        ],
        col_widths=[5*cm, 6*cm, 5.5*cm]
    )
    story += [sp(2)]

    story += h1("6. Patron Strategy")
    story += h2("6.1 ScoringService - ms-coincidencias")
    story += body(
        "El algoritmo de puntuacion de coincidencias encapsula cuatro criterios ponderados. "
        "Al implementarlo como Strategy, los pesos pueden cambiarse sin tocar el controlador ni el listener:"
    )
    story += tabla(
        ["Criterio", "Herramienta", "Peso"],
        [
            ["Similitud del nombre",      "FuzzyWuzzy ratio()",        "40%"],
            ["Similitud de descripcion",  "FuzzyWuzzy partial_ratio()", "30%"],
            ["Distancia geografica",      "Formula Haversine",         "20%"],
            ["Diferencia temporal",       "ChronoUnit.DAYS",           "10%"],
        ],
        col_widths=[5.5*cm, 5*cm, 2.5*cm]
    )
    story += code(
        "// ScoringService.java\n"
        "public double calcularPuntaje(CandidatoDTO c, ReporteNuevoEvent r) {\n"
        "    double nombre = fuzzy.ratio(c.getNombre(), r.getNombre()) / 100.0;\n"
        "    double desc   = fuzzy.partialRatio(c.getDescripcion(), r.getDescripcion()) / 100.0;\n"
        "    double dist   = calcularDistancia(c.getLat(), c.getLon(), r.getLat(), r.getLon());\n"
        "    double tiempo = calcularTiempo(c.getFecha(), r.getFecha());\n"
        "    return 0.40*nombre + 0.30*desc + 0.20*dist + 0.10*tiempo;\n"
        "}"
    )
    story += h2("6.2 ClusteringService - ms-geolocalizacion")
    story += body(
        "Aplica el algoritmo K-means para agrupar reportes geograficamente. "
        "La encapsulacion en ClusteringService permite sustituir K-means por DBSCAN "
        "sin impactar al GeoController."
    )
    story += [sp(2)]

    story += h1("7. Patron Context/Provider (Frontend React)")
    story += body(
        "El estado de autenticacion (token JWT, datos del usuario, funciones login/logout) "
        "necesita ser accesible desde multiples componentes sin prop-drilling."
    )
    story += code(
        "// frontend/src/context/AuthContext.jsx\n"
        "export const AuthContext = createContext();\n\n"
        "export function AuthProvider({ children }) {\n"
        "  const [user, setUser] = useState(null);\n"
        "  const login  = async (creds) => { /* llama al BFF */ };\n"
        "  const logout = () => { setUser(null); };\n"
        "  return (\n"
        "    <AuthContext.Provider value={{ user, login, logout }}>\n"
        "      {children}\n"
        "    </AuthContext.Provider>\n"
        "  );\n"
        "}"
    )
    story += [sp(2)]

    story += h1("8. Patron Circuit Breaker (Resilience4j)")
    story += body(
        "Si un microservicio aguas abajo falla o se vuelve lento, "
        "el BFF-Service puede colapsar acumulando threads bloqueados. El Circuit Breaker "
        "detecta el fallo y retorna un fallback inmediato, protegiendo la estabilidad:"
    )
    story += tabla(
        ["Estado", "Descripcion", "Condicion de transicion"],
        [
            ["CLOSED",   "Trafico normal, todas las llamadas pasan",  "Default"],
            ["OPEN",     "Bloquea llamadas, retorna fallback inmediato","50%+ fallos en ventana deslizante"],
            ["HALF_OPEN","Permite llamadas de prueba para recuperar",  "Tras timeout configurado"],
        ],
        col_widths=[3*cm, 6*cm, 7.5*cm]
    )
    story += [sp(2)]

    story += h1("9. Arquetipos Maven")
    story += h2("9.1 Spring Boot Starter Parent (arquetipo oficial)")
    story += body(
        "Todos los microservicios heredan de spring-boot-starter-parent 3.2.5, "
        "el arquetipo oficial que provee gestion de versiones, plugins de compilacion, "
        "configuracion de JaCoCo y empaquetado como fat-jar."
    )
    story += h2("9.2 Arquetipo personalizado - sanos-y-salvos-microservice-archetype")
    story += body(
        "Ubicado en /maven-archetypes/sanos-y-salvos-microservice-archetype. "
        "Genera la estructura base de cualquier nuevo microservicio del ecosistema:"
    )
    story += bullet([
        "Application.java con @SpringBootApplication",
        "JwtAuthFilter.java — validacion de tokens JWT en cada request",
        "SecurityConfig.java — cadena de filtros Spring Security (stateless)",
        "RabbitMQConfig.java — TopicExchange, Queue y Binding preconfigurados",
        "application.yml con placeholders para puerto, datasource y rabbitmq",
        "ApplicationTests.java con test contextLoads()",
        "pom.xml con todas las dependencias del ecosistema (web, jpa, amqp, security, jjwt, postgresql, jacoco)",
    ])
    story += h2("9.3 Generacion de nuevo microservicio")
    story += code(
        "# Instalar el arquetipo en el repositorio local Maven\n"
        "cd maven-archetypes/sanos-y-salvos-microservice-archetype\n"
        "mvn install\n\n"
        "# Generar nuevo servicio\n"
        "mvn archetype:generate \\\n"
        "  -DarchetypeGroupId=com.sanosysalvos \\\n"
        "  -DarchetypeArtifactId=sanos-y-salvos-microservice-archetype \\\n"
        "  -DarchetypeVersion=1.0.0 \\\n"
        "  -DgroupId=com.sanosysalvos \\\n"
        "  -DartifactId=ms-nuevo \\\n"
        "  -DserviceName=Nuevo \\\n"
        "  -DservicePort=8085 \\\n"
        "  -DdatabaseName=nuevo_db"
    )

    story += h1("10. Justificacion de patrones seleccionados")
    story += tabla(
        ["Patron", "Alternativa descartada", "Razon de eleccion"],
        [
            ["Factory Method", "if/else en el servicio",
             "Viola OCP; agregar tipos requiere modificar codigo existente"],
            ["Observer (RabbitMQ)", "Llamadas REST sincronas directas",
             "Desacoplamiento total; resiliencia ante fallos parciales"],
            ["Proxy (BFF)", "Frontend llama directo a cada microservicio",
             "Un solo punto de entrada facilita auth, logging y versionado de API"],
            ["Strategy (Scoring)", "Algoritmo directo en el listener",
             "Permite cambiar pesos/criterios sin tocar el flujo de eventos"],
            ["Circuit Breaker", "Sin resiliencia",
             "Evita cascada de fallos; mejora UX con respuestas rapidas de fallback"],
        ],
        col_widths=[3.5*cm, 4.5*cm, 8.5*cm]
    )

    doc.build(story)
    print("  OK  " + path)


# ============================================================================
# PDF 2 — PLAN DE BRANCHING
# ============================================================================
def generar_branching():
    path = "docs/PLAN_BRANCHING.pdf"
    doc = SimpleDocTemplate(path, pagesize=A4,
                            leftMargin=MARGIN, rightMargin=MARGIN,
                            topMargin=MARGIN, bottomMargin=MARGIN)
    story = []

    story += portada(
        "PLAN DE BRANCHING - GIT FLOW",
        "Estrategia de ramas, flujo de trabajo, Conventional Commits "
        "y evidencia de merges del proyecto",
        "Plataforma de reporte y localizacion de mascotas perdidas"
    )

    story += h1("1. Introduccion")
    story += body(
        "El proyecto Sanos y Salvos adopta Git Flow como estrategia de branching. "
        "Git Flow define un conjunto de reglas sobre como crear, nombrar, fusionar y eliminar ramas, "
        "garantizando que el codigo en master siempre sea estable y desplegable a produccion."
    )
    story += body(
        "Este documento describe la estructura de ramas, el flujo de trabajo, "
        "la convencion de mensajes de commit, la resolucion de conflictos, "
        "y evidencia de las ramas creadas y fusionadas durante el desarrollo del EP2."
    )
    story += [sp(2)]

    story += h1("2. Estructura de ramas")
    story += tabla(
        ["Rama", "Tipo", "Descripcion", "Merge destino"],
        [
            ["master",   "Principal",   "Codigo en produccion; solo recibe merges desde develop o hotfix", "—"],
            ["develop",  "Integracion", "Rama de integracion continua de features del sprint",             "master"],
            ["feature/*","Temporal",    "Una rama por funcionalidad o tarea del sprint",                   "develop"],
            ["hotfix/*", "Temporal",    "Correccion urgente directamente sobre master",                    "master + develop"],
            ["release/*","Temporal",    "Preparacion de version: bumps, changelog, QA final",              "master + develop"],
        ],
        col_widths=[3*cm, 3*cm, 7.5*cm, 3*cm]
    )
    story += h2("2.1 Diagrama de flujo")
    story += code(
        "master  -------------------------------------------------------► produccion\n"
        "  |-- develop  ----------------------------------------► integracion\n"
        "        |-- feature/readme-servicios ----|\n"
        "        |-- feature/tests-bff -----------|-- merge --no-ff\n"
        "        |-- feature/maven-archetype ------|"
    )
    story += [sp(2)]

    story += h1("3. Flujo de trabajo estandar")
    story += h2("Paso 1 - Crear rama feature desde develop")
    story += code(
        "git checkout develop\n"
        "git pull origin develop\n"
        "git checkout -b feature/nombre-funcionalidad"
    )
    story += h2("Paso 2 - Desarrollar y hacer commits")
    story += code(
        "git add archivo.java\n"
        "git commit -m \"feat(modulo): descripcion breve en imperativo\""
    )
    story += h2("Paso 3 - Mantener la rama actualizada")
    story += code(
        "git fetch origin develop\n"
        "git rebase origin/develop"
    )
    story += h2("Paso 4 - Merge a develop con --no-ff")
    story += code(
        "git checkout develop\n"
        "git merge --no-ff feature/nombre-funcionalidad\n"
        "git push origin develop"
    )
    story += body(
        "El flag --no-ff (no fast-forward) es obligatorio: preserva el historial de la rama "
        "feature como un bloque de commits agrupados, haciendo la historia del proyecto legible y auditable."
    )
    story += h2("Paso 5 - Eliminar rama feature")
    story += code(
        "git branch -d feature/nombre-funcionalidad\n"
        "git push origin --delete feature/nombre-funcionalidad"
    )
    story += h2("Paso 6 - Merge de develop a master (release)")
    story += code(
        "git checkout master\n"
        "git merge --no-ff develop\n"
        "git tag -a v1.0.0 -m \"Release version 1.0.0\"\n"
        "git push origin master --tags"
    )
    story += [sp(2)]

    story += h1("4. Conventional Commits")
    story += body(
        "Todos los mensajes de commit siguen la especificacion Conventional Commits v1.0. "
        "Esto permite generar changelogs automaticos y entender el impacto de cada cambio "
        "con solo leer el historial git log:"
    )
    story += code("tipo(alcance): descripcion breve en imperativo, presente, minusculas")
    story += tabla(
        ["Tipo", "Cuando usarlo", "Ejemplo"],
        [
            ["feat",     "Nueva funcionalidad",                  "feat(mascotas): agregar endpoint de reporte"],
            ["fix",      "Correccion de bug",                    "fix(auth): corregir validacion de token expirado"],
            ["docs",     "Solo documentacion",                   "docs(readme): actualizar instrucciones de deploy"],
            ["test",     "Agregar o corregir tests",             "test(bff): agregar tests de AuthProxyService"],
            ["chore",    "Mantenimiento, dependencias, build",   "chore(deps): actualizar spring-boot a 3.2.5"],
            ["refactor", "Refactorizacion sin cambio funcional", "refactor(geo): extraer logica de clustering"],
        ],
        col_widths=[2.5*cm, 6*cm, 8*cm]
    )
    story += [sp(2)]

    story += h1("5. Resolucion de conflictos de merge")
    story += body(
        "Cuando dos ramas modifican el mismo archivo, Git marca el conflicto con delimitadores. "
        "El desarrollador debe resolver manualmente antes de completar el merge:"
    )
    story += code(
        "<<<<<<< HEAD  (rama destino - develop)\n"
        "public String getNombre() { return nombre.trim(); }\n"
        "=======\n"
        "public String getNombre() { return nombre.toUpperCase(); }\n"
        ">>>>>>> feature/mejora-nombre  (rama fuente)\n\n"
        "# Resolucion: combinar ambas intenciones\n"
        "public String getNombre() { return nombre.trim().toUpperCase(); }"
    )
    story += h2("Protocolo de resolucion")
    story += bullet([
        "Identificar el conflicto: git status muestra archivos con 'both modified'.",
        "Abrir el archivo y decidir que logica conservar (o combinar ambas).",
        "Eliminar los marcadores <<<<<<, ======, >>>>>>.",
        "Ejecutar: git add archivo && git commit (con mensaje automatico de merge).",
        "Ejecutar las pruebas unitarias para verificar que no hay regresiones.",
        "Si el conflicto es complejo, coordinar con el autor de la otra rama antes de resolver.",
    ])
    story += [sp(2)]

    story += h1("6. Evidencia de ramas y merges")
    story += h2("6.1 Ramas creadas durante EP2")
    story += tabla(
        ["Rama", "Origen", "Proposito"],
        [
            ["develop",                      "master",  "Rama de integracion principal del proyecto"],
            ["feature/readme-servicios",     "develop", "Documentacion README de los 6 componentes"],
            ["feature/tests-bff",            "develop", "14 pruebas unitarias para bff-service"],
            ["feature/maven-archetype",      "develop", "Arquetipo Maven personalizado completo"],
            ["claude/implement-fullstack-components-P80HS", "master", "Rama de trabajo principal del EP2"],
        ],
        col_widths=[6*cm, 2.5*cm, 8*cm]
    )
    story += h2("6.2 Merges realizados con --no-ff")
    story += tabla(
        ["Merge", "Comando", "Resultado"],
        [
            ["feature/readme-servicios a develop",
             "git merge --no-ff feature/readme-servicios",
             "Merge commit creado; rama feature eliminada"],
            ["feature/tests-bff a develop",
             "git merge --no-ff feature/tests-bff",
             "Merge commit creado; rama feature eliminada"],
            ["develop a master",
             "git merge --no-ff develop",
             "Version estable actualizada en master"],
        ],
        col_widths=[4.5*cm, 6*cm, 6*cm]
    )
    story += h2("6.3 Historial de commits representativo")
    story += code(
        "* feat(docs): agregar documentacion de patrones de diseno y branching\n"
        "* feat(tests): agregar 14 pruebas unitarias para bff-service\n"
        "* feat(archetype): crear arquetipo maven sanos-y-salvos-microservice\n"
        "* feat(readme): agregar README a todos los componentes del sistema\n"
        "* chore(init): estructura inicial del monorepo Sanos y Salvos"
    )
    story += [sp(2)]

    story += h1("7. Integracion CI/CD - GitHub Actions")
    story += body(
        "El repositorio incluye workflows de GitHub Actions que automatizan la integracion continua. "
        "Cada push a una rama feature dispara el pipeline de validacion:"
    )
    story += tabla(
        ["Evento", "Pipeline", "Jobs ejecutados"],
        [
            ["push a feature/*",       "ci-feature.yml", "compile → test → jacoco-report"],
            ["pull_request a develop", "ci-pr.yml",      "compile → test → lint → jacoco"],
            ["merge a master",         "cd-deploy.yml",  "build-images → push-ecr → deploy-ecs"],
        ],
        col_widths=[4*cm, 4*cm, 8.5*cm]
    )
    story += [sp(2)]

    story += h1("8. Politica de proteccion de ramas")
    story += bullet([
        "master y develop tienen proteccion contra push directo.",
        "Todo cambio a develop requiere Pull Request con al menos 1 aprobacion.",
        "Los merges directos a master solo se realizan desde develop (release) o hotfix/*.",
        "Esta prohibido hacer git push --force sobre master o develop.",
        "Cada PR debe tener CI verde (tests + cobertura mayor al 70%) antes de mergear.",
    ])
    story += [sp(2)]

    story += h1("9. Referencia rapida de comandos")
    story += code(
        "# Ver todas las ramas (local + remoto)\n"
        "git branch -a\n\n"
        "# Ver historial con grafo de merges\n"
        "git log --oneline --graph --all\n\n"
        "# Crear y cambiar a nueva feature\n"
        "git checkout -b feature/mi-feature develop\n\n"
        "# Mergear con --no-ff\n"
        "git checkout develop && git merge --no-ff feature/mi-feature\n\n"
        "# Taggear una version\n"
        "git tag -a v1.2.0 -m 'Release 1.2.0' && git push origin --tags\n\n"
        "# Ver commits de una rama especifica\n"
        "git log --oneline develop..feature/mi-feature"
    )

    doc.build(story)
    print("  OK  " + path)


# ============================================================================
if __name__ == "__main__":
    os.makedirs("docs", exist_ok=True)
    print("Generando PDFs...")
    generar_patrones()
    generar_branching()
    print("Listo! PDFs generados en docs/")
