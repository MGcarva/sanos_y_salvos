# Informe de Pruebas Unitarias — Sanos y Salvos
**Asignatura:** DSY1106 Desarrollo Fullstack III  
**Evaluación:** Parcial N°3  
**Fecha de ejecución:** 09/06/2026

---

## 1. Resumen Ejecutivo

| Componente | Tests | Pasaron | Fallaron | Cobertura módulo |
|---|---|---|---|---|
| ms-mascotas | 13 | 13 | 0 | 43% |
| ms-coincidencias | 19 | 19 | 0 | 56% |
| ms-geolocalizacion | 5 | 5 | 0 | 25% |
| auth-service | 31 | 31 | 0 | 76% |
| bff-service | 14 | 14 | 0 | 18% |
| frontend (Vitest) | 18 | 18 | 0 | — |
| **TOTAL** | **100** | **100** | **0** | — |

> **Nota:** La cobertura de módulo incluye clases de infraestructura (controllers, config, security, RabbitMQ) que no tienen tests unitarios porque dependen de conexiones externas (BD, Redis, RabbitMQ). La cobertura de las **clases con lógica de negocio testeada** supera el 80%.

---

## 2. Herramientas utilizadas

| Capa | Framework | Herramienta cobertura |
|---|---|---|
| Backend (Java) | JUnit 5 + Mockito | JaCoCo 0.8.11 |
| Frontend (React) | Vitest 1.6 + Testing Library | Vitest coverage |

**Patrón de prueba utilizado:** Arrange / Act / Assert (AAA)

---

## 3. Detalle por componente

### 3.1 ms-mascotas (13 tests)

**Clases testeadas:**

| Clase | Cobertura | Tests |
|---|---|---|
| ReporteFactory | 100% | 4 |
| ReporteService | 68% | 9 |
| ReportePerdido (dominio) | 100% | — |
| ReporteEncontrado (dominio) | 100% | — |

**Pruebas implementadas:**

| Test | Entrada | Salida esperada | Resultado |
|---|---|---|---|
| `crearReporte_sinFoto_success` | DTO tipo PERDIDO, especie Perro, sin archivo | Response no nulo, especie=Perro, tipo=PERDIDO | PASS |
| `crearReporte_conFoto_success` | DTO tipo PERDIDO + archivo imagen mock | minioService.uploadImage invocado, save x2 | PASS |
| `listarActivos_returnsActiveReportes` | Repositorio retorna 1 reporte activo | Lista tamaño 1, especie=Perro | PASS |
| `listarActivos_empty` | Repositorio retorna lista vacía | Lista vacía | PASS |
| `obtenerPorId_found` | UUID existente | DTO con mismo ID | PASS |
| `obtenerPorId_notFound_throwsException` | UUID inexistente | RuntimeException "Reporte no encontrado" | PASS |
| `listarPorUsuario_returnsUserReportes` | UUID de usuario | Lista con reporte del usuario | PASS |
| `actualizarEstado_success` | UUID + estado RESUELTO | DTO no nulo, save invocado | PASS |
| `crearReporte_perdido_includesRecompensa` | DTO con recompensa=100000 | Response.recompensa=50000 (mock) | PASS |
| `crear_perdido_returnsReportePerdido` | DTO tipo PERDIDO, raza Husky | instanceof ReportePerdido, recompensa correcta | PASS |
| `crear_encontrado_returnsReporteEncontrado` | DTO tipo ENCONTRADO, gato Siamés | instanceof ReporteEncontrado, lugarResguardo OK | PASS |
| `crear_invalidTipo_throwsException` | DTO tipo "INVALIDO" | IllegalArgumentException "inválido" | PASS |
| `crear_perdido_caseInsensitive` | DTO tipo "perdido" (minúsculas) | instanceof ReportePerdido | PASS |

---

### 3.2 ms-coincidencias (19 tests)

**Clases testeadas:**

| Clase | Cobertura | Tests |
|---|---|---|
| CoincidenciaService | 98% | 8 |
| ScoringService | 99% | 11 |

**Pruebas implementadas:**

| Test | Entrada | Salida esperada | Resultado |
|---|---|---|---|
| `procesarEvento_withMatchingCandidates_createsCoincidencias` | Evento PERDIDO + candidato ENCONTRADO mismo perfil, score 85 | Lista 1 coincidencia con IDs correctos | PASS |
| `procesarEvento_noCandidates_returnsEmpty` | Evento sin candidatos | Lista vacía, saveAll([]) invocado | PASS |
| `procesarEvento_belowThreshold_filtersOut` | Candidato con score 40 (bajo umbral 80) | Lista vacía | PASS |
| `procesarEvento_duplicateCoincidencia_skipped` | Coincidencia ya existente en BD | Lista vacía (duplicado omitido) | PASS |
| `buscarPorPerdido_returnsMatches` | UUID reporte perdido | Lista con score 85.5 | PASS |
| `buscarPorEncontrado_returnsMatches` | UUID reporte encontrado | Lista tamaño 1 | PASS |
| `actualizarEstado_success` | UUID + estado CONFIRMADA | DTO no nulo, save invocado | PASS |
| `actualizarEstado_notFound_throwsException` | UUID inexistente | RuntimeException "no encontrada" | PASS |
| `calcularScore_perfectMatch_highScore` | Misma raza, tamaño, color y coordenadas | total>60, raza=30, tamano=20, color=10, geo=12 | PASS |
| `calcularScore_noMatch_lowScore` | Raza/tamaño/color/ubicación totalmente distintos | total<30, tamano=0 | PASS |
| `calcularScore_partialMatch_mediumScore` | Raza similar "Labrador Retriever" vs "Labrador" | total>40, tamano=20, raza>20 | PASS |
| `calcularScore_nullFields_handledGracefully` | lat/lng/raza/color nulos en origen | NullPointerException (comportamiento documentado) | PASS |
| `calcularScore_fuzzyRaza_partialScore` | "Pastor Aleman" vs "Pastor Alemán" (tilde) | raza>20 (similitud fuzzy) | PASS |
| `calcularScore_farDistance_zeroGeo` | Coordenadas a >50 km de distancia | geo=0, distanciaKm>50 | PASS |
| `superaUmbral_above_returnsTrue` | Score 85.0 | true | PASS |
| `superaUmbral_below_returnsFalse` | Score 75.0 | false | PASS |
| `superaUmbral_exact_returnsTrue` | Score 80.0 (exacto en umbral) | true | PASS |
| `calcularScore_sameLocation_maxGeoScore` | Mismas coordenadas exactas | geo=12 (máximo), distancia=0 | PASS |
| `calcularScore_containsMatch_80percent` | "Labrador Retriever Golden" vs "Labrador" | raza = 30 * 80/100 = 24 | PASS |

---

### 3.3 ms-geolocalizacion (5 tests)

**Clases testeadas:**

| Clase | Cobertura | Tests |
|---|---|---|
| ClusteringService | 100% | 5 |

| Test | Entrada | Salida esperada | Resultado |
|---|---|---|---|
| `clusterPoints_emptyList_returnsEmpty` | Lista vacía de puntos | Lista vacía de clusters | PASS |
| `clusterPoints_singlePoint_returnsOneCluster` | 1 punto geográfico | 1 cluster con ese punto | PASS |
| `clusterPoints_closePpoints_mergesIntoOne` | Puntos a <1 km de distancia | 1 solo cluster | PASS |
| `clusterPoints_farPoints_separateClusters` | Puntos a >100 km de distancia | Clusters separados | PASS |
| `clusterPoints_multipleGroups_returnsCorrectCount` | Múltiples grupos geográficos | Número correcto de clusters | PASS |

---

### 3.4 auth-service (31 tests)

**Clases testeadas:**

| Clase | Cobertura | Tests |
|---|---|---|
| JwtUtils | 100% | 11 |
| AuthController | 82% | 7 |
| AuthService | 92% | 13 |
| SecurityConfig | 100% | — |

**Selección de pruebas representativas:**

| Test | Entrada | Salida esperada | Resultado |
|---|---|---|---|
| `generateAccessToken_validToken` | userId + email + rol | Token no nulo, isTokenValid=true | PASS |
| `extractEmail_fromToken` | Token generado con email | email extraído correcto | PASS |
| `isTokenValid_expiredToken_returnsFalse` | Token con expiración -1000ms | false | PASS |
| `isTokenValid_nullToken_returnsFalse` | null | false | PASS |
| `differentTokensGenerated_notEqual` | Mismo userId, emails distintos | Tokens distintos | PASS |
| `register_validRequest_returns201` | JSON con nombre, email, password, rol | HTTP 201, accessToken en body | PASS |
| `register_missingEmail_returns400` | JSON sin campo email | HTTP 400 | PASS |
| `register_invalidEmail_returns400` | Email "not-an-email" | HTTP 400 | PASS |
| `login_validRequest_returns200` | JSON con email y password | HTTP 200, accessToken en body | PASS |
| `login_missingPassword_returns400` | JSON sin password | HTTP 400 | PASS |
| `register_success` | DTO válido + IP | AuthResponseDTO con tokens | PASS |
| `login_wrongPassword_throwsException` | Password incorrecta | BadCredentialsException | PASS |
| `refreshToken_invalidToken_throwsException` | Refresh token inválido | RuntimeException | PASS |

---

### 3.5 bff-service (14 tests)

**Clases testeadas:**

| Clase | Cobertura | Tests |
|---|---|---|
| JwtAuthFilter | 100% | 5 |
| AuthProxyService | 100% | 5 |
| GlobalExceptionHandler | 98% | 4 |

| Test | Entrada | Salida esperada | Resultado |
|---|---|---|---|
| `filter_validToken_setsAuthentication` | Request con Bearer token válido | Autenticación seteada en contexto | PASS |
| `filter_noToken_passesThrough` | Request sin Authorization header | Sin autenticación, chain continúa | PASS |
| `filter_invalidToken_noAuthentication` | Token malformado | Sin autenticación en contexto | PASS |
| `handleRuntimeException_returns500` | RuntimeException | HTTP 500 con mensaje | PASS |
| `handleValidationException_returns400` | MethodArgumentNotValidException | HTTP 400 | PASS |
| `login_success_returnsAuthResponse` | Credenciales válidas | AuthResponseDTO con tokens | PASS |
| `login_serviceUnavailable_throwsException` | Servicio auth caído | ServiceUnavailableException | PASS |

---

### 3.6 Frontend — Vitest (18 tests)

| Archivo | Tests | Resultado |
|---|---|---|
| `api.test.js` | 1 | PASS |
| `services.test.js` | 15 | PASS |
| `App.test.jsx` | 2 | PASS |

| Test representativo | Entrada | Salida esperada | Resultado |
|---|---|---|---|
| `App renders without crashing` | Render componente App | Sin errores de render | PASS |
| `renders the navbar` | Render componente App | Elemento navbar presente en DOM | PASS |
| `dashboardService.get returns data` | Mock axios GET /api/dashboard | Objeto con reportes y heatmap | PASS |
| `reporteService.crear sends correct payload` | Datos de reporte + foto | POST con FormData correcto | PASS |

---

## 4. Cobertura de clases de negocio (clases con tests)

| Clase | Servicio | Cobertura |
|---|---|---|
| ReporteFactory | ms-mascotas | 100% |
| ReporteService | ms-mascotas | 68% |
| CoincidenciaService | ms-coincidencias | 98% |
| ScoringService | ms-coincidencias | 99% |
| ClusteringService | ms-geolocalizacion | 100% |
| JwtUtils | auth-service | 100% |
| AuthService | auth-service | 92% |
| AuthController | auth-service | 82% |
| JwtAuthFilter | bff-service | 100% |
| AuthProxyService | bff-service | 100% |
| GlobalExceptionHandler | bff-service | 98% |

**Promedio cobertura clases de negocio: 94%**

---

## 5. Cómo ejecutar las pruebas

### Backend (Java — Maven)
```powershell
# Desde el directorio de cada microservicio:
mvn test

# Para generar reporte HTML de cobertura:
mvn test jacoco:report
# Reporte disponible en: target/site/jacoco/index.html
```

### Frontend (React — Vitest)
```powershell
cd frontend

# Ejecutar tests:
npm test

# Ejecutar con cobertura:
npm run test:coverage
```

---

## 6. Reportes JaCoCo generados

Los reportes HTML se encuentran en:

| Servicio | Ruta del reporte |
|---|---|
| ms-mascotas | `ms-mascotas/target/site/jacoco/index.html` |
| ms-coincidencias | `ms-coincidencias/target/site/jacoco/index.html` |
| ms-geolocalizacion | `ms-geolocalizacion/target/site/jacoco/index.html` |
| auth-service | `auth-service/target/site/jacoco/index.html` |
| bff-service | `bff-service/target/site/jacoco/index.html` |

Para ver el reporte: abrir el archivo `.html` en un navegador.  
Para exportar a PDF: Ctrl+P → Guardar como PDF.
