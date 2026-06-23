# Tests Unitarios — Sanos y Salvos

> **Requisito mínimo EP3:** 60% cobertura por módulo  
> **Total tests unitarios:** 77 tests en 5 módulos  
> **Herramientas:** JUnit 5 · Mockito · AssertJ · JaCoCo  
> **No se necesita instalar Java ni Maven** — se usa Docker

---

## Comando para correr tests (sin Java instalado)

### Correr TODOS los módulos de una vez
```powershell
docker run --rm -v "c:\Users\LENOVO\sanos_y_salvos:/app" -w /app maven:3.9-eclipse-temurin-21-alpine mvn test --no-transfer-progress "-Dexclude=**/*ApplicationTests.java"
```

### Correr un módulo específico
```powershell
# auth-service (31 tests)
docker run --rm -v "c:\Users\LENOVO\sanos_y_salvos:/app" -w /app maven:3.9-eclipse-temurin-21-alpine mvn test -pl auth-service --no-transfer-progress "-Dexclude=**/*ApplicationTests.java"

# bff-service (14 tests)
docker run --rm -v "c:\Users\LENOVO\sanos_y_salvos:/app" -w /app maven:3.9-eclipse-temurin-21-alpine mvn test -pl bff-service --no-transfer-progress "-Dexclude=**/*ApplicationTests.java"

# ms-mascotas (13 tests)
docker run --rm -v "c:\Users\LENOVO\sanos_y_salvos:/app" -w /app maven:3.9-eclipse-temurin-21-alpine mvn test -pl ms-mascotas --no-transfer-progress "-Dexclude=**/*ApplicationTests.java"

# ms-coincidencias (19 tests)
docker run --rm -v "c:\Users\LENOVO\sanos_y_salvos:/app" -w /app maven:3.9-eclipse-temurin-21-alpine mvn test -pl ms-coincidencias --no-transfer-progress "-Dexclude=**/*ApplicationTests.java"

# ms-geolocalizacion (5 tests)
docker run --rm -v "c:\Users\LENOVO\sanos_y_salvos:/app" -w /app maven:3.9-eclipse-temurin-21-alpine mvn test -pl ms-geolocalizacion --no-transfer-progress "-Dexclude=**/*ApplicationTests.java"
```

### Correr UN test específico
```powershell
# Ejemplo: solo el test crearReporte_conFoto_success de ms-mascotas
docker run --rm -v "c:\Users\LENOVO\sanos_y_salvos:/app" -w /app maven:3.9-eclipse-temurin-21-alpine mvn test -pl ms-mascotas --no-transfer-progress "-Dtest=ReporteServiceTest#crearReporte_conFoto_success"

# Ejemplo: solo AuthServiceTest completo
docker run --rm -v "c:\Users\LENOVO\sanos_y_salvos:/app" -w /app maven:3.9-eclipse-temurin-21-alpine mvn test -pl auth-service --no-transfer-progress "-Dtest=AuthServiceTest"
```

---

## Detalle de tests por módulo

---

### auth-service — 31 tests

#### `AuthServiceTest.java` (13 tests) — Patrón: Mock Objects
| Test | Qué verifica |
|------|-------------|
| `register_success` | Registro exitoso de nuevo usuario |
| `register_duplicateEmail_throwsException` | Email duplicado lanza excepción |
| `register_rateLimited_throwsException` | Rate limiting en registro |
| `login_success` | Login con credenciales correctas retorna tokens |
| `login_invalidPassword_throwsException` | Contraseña incorrecta lanza excepción |
| `login_lockedAccount_throwsException` | Cuenta bloqueada no permite login |
| `login_emailNotVerified_throwsException` | Email no verificado bloquea login |
| `login_userNotFound_throwsException` | Usuario inexistente lanza excepción |
| `refreshToken_success` | Refresh token válido genera nuevo access token |
| `refreshToken_expired_throwsException` | Refresh token expirado lanza excepción |
| `verifyEmail_success` | Token de verificación válido activa cuenta |
| `verifyEmail_expiredToken_throwsException` | Token de verificación expirado lanza excepción |
| `login_fiveFailedAttempts_locksAccount` | 5 intentos fallidos bloquean la cuenta |

#### `JwtUtilsTest.java` (11 tests) — Patrón: Pure Unit Test
| Test | Qué verifica |
|------|-------------|
| `generateAccessToken_validToken` | Genera access token JWT válido |
| `extractEmail_fromToken` | Extrae email del payload JWT |
| `extractUserId_fromToken` | Extrae userId del payload JWT |
| `extractRol_fromToken` | Extrae rol del payload JWT |
| `isTokenValid_invalidToken_returnsFalse` | Token inválido retorna false |
| `isTokenValid_nullToken_returnsFalse` | Token null retorna false |
| `isTokenValid_emptyToken_returnsFalse` | Token vacío retorna false |
| `isTokenValid_expiredToken_returnsFalse` | Token expirado retorna false |
| `getAccessExpiration_returnsConfigured` | Expiración configurada es correcta |
| `generateRefreshToken_validToken` | Genera refresh token válido |
| `differentTokensGenerated_notEqual` | Dos tokens distintos son diferentes |

#### `AuthControllerTest.java` (7 tests) — Patrón: Mock MVC
| Test | Qué verifica |
|------|-------------|
| `register_validRequest_returns201` | POST /auth/register retorna 201 |
| `register_missingEmail_returns400` | Falta email retorna 400 |
| `register_invalidEmail_returns400` | Email inválido retorna 400 |
| `login_validRequest_returns200` | POST /auth/login retorna 200 |
| `login_missingPassword_returns400` | Falta password retorna 400 |
| `refresh_validRequest_returns200` | POST /auth/refresh retorna 200 |
| `verifyEmail_validToken_returns200` | GET /auth/verify retorna 200 |

---

### bff-service — 14 tests

#### `AuthProxyServiceTest.java` (5 tests) — Patrón: Mock Objects
| Test | Qué verifica |
|------|-------------|
| `login_debeRetornarTokenCuandoCredencialesCorrectas` | Proxy reenvía login al auth-service |
| `login_debePropagarErrorCuandoCredencialesInvalidas` | Propaga error del auth-service |
| `register_debeLlamarEndpointCorrecto` | Proxy llama endpoint correcto de registro |
| `refresh_debeRenovarTokenCorrectamente` | Proxy reenvía refresh token |
| `verifyEmail_debeLlamarEndpointGetConToken` | Proxy reenvía verificación de email |

#### `JwtAuthFilterTest.java` (5 tests) — Patrón: Mock Objects
| Test | Qué verifica |
|------|-------------|
| `filtro_sinHeader_debeContinuarSinAutenticacion` | Sin Authorization header continúa sin auth |
| `filtro_conTokenValido_debeEstablecerAutenticacion` | Token válido establece SecurityContext |
| `filtro_conTokenInvalido_debeIgnorarYContinuar` | Token inválido ignora y continúa |
| `filtro_conHeaderSinBearer_debeContinuarSinAutenticacion` | Header sin "Bearer " continúa sin auth |
| `filtro_conTokenExpirado_debeIgnorarYContinuar` | Token expirado ignora y continúa |

#### `GlobalExceptionHandlerTest.java` (4 tests) — Patrón: Pure Unit Test
| Test | Qué verifica |
|------|-------------|
| `handleClientError_debeRetornarMismoStatusCode` | Error de cliente retorna mismo status code |
| `handleClientError_cuandoBodyNoEsJson_debeRetornarMensajeRaw` | Body no-JSON retorna mensaje raw |
| `handleServerError_debeRetornar500CuandoMicroservicioCae` | Error de servidor retorna 500 |
| `handleClientError_cuandoBodyEsNull_debeRetornarMapaConMensaje` | Body null retorna mapa con mensaje |

---

### ms-mascotas — 13 tests

#### `ReporteFactoryTest.java` (4 tests) — Patrón: Factory Method
| Test | Qué verifica |
|------|-------------|
| `crear_perdido_returnsReportePerdido` | Factory crea ReportePerdido correctamente |
| `crear_encontrado_returnsReporteEncontrado` | Factory crea ReporteEncontrado correctamente |
| `crear_invalidTipo_throwsException` | Tipo inválido lanza excepción |
| `crear_perdido_caseInsensitive` | Tipo acepta mayúsculas/minúsculas |

#### `ReporteServiceTest.java` (9 tests) — Patrón: Mock Objects
| Test | Qué verifica |
|------|-------------|
| `crearReporte_sinFoto_success` | Crea reporte sin imagen correctamente |
| `crearReporte_conFoto_success` | Crea reporte con imagen (sube a MinIO) |
| `listarActivos_returnsActiveReportes` | Lista solo reportes activos |
| `listarActivos_empty` | Lista vacía retorna lista vacía |
| `obtenerPorId_found` | Obtiene reporte por ID existente |
| `obtenerPorId_notFound_throwsException` | ID inexistente lanza excepción |
| `listarPorUsuario_returnsUserReportes` | Lista reportes filtrados por usuario |
| `actualizarEstado_success` | Actualiza estado del reporte correctamente |
| `crearReporte_perdido_includesRecompensa` | Reporte perdido incluye campo recompensa |

---

### ms-coincidencias — 19 tests

#### `CoincidenciaServiceTest.java` (8 tests) — Patrón: Mock Objects
| Test | Qué verifica |
|------|-------------|
| `procesarEvento_withMatchingCandidates_createsCoincidencias` | Evento RabbitMQ crea coincidencias válidas |
| `procesarEvento_noCandidates_returnsEmpty` | Sin candidatos retorna lista vacía |
| `procesarEvento_belowThreshold_filtersOut` | Score bajo umbral no crea coincidencia |
| `procesarEvento_duplicateCoincidencia_skipped` | Coincidencia duplicada se omite |
| `buscarPorPerdido_returnsMatches` | Busca coincidencias por reporte perdido |
| `buscarPorEncontrado_returnsMatches` | Busca coincidencias por reporte encontrado |
| `actualizarEstado_success` | Actualiza estado de coincidencia |
| `actualizarEstado_notFound_throwsException` | ID inexistente lanza excepción |

#### `ScoringServiceTest.java` (11 tests) — Patrón: Pure Unit Test
| Test | Qué verifica |
|------|-------------|
| `calcularScore_perfectMatch_highScore` | Match perfecto da score alto |
| `calcularScore_noMatch_lowScore` | Sin coincidencias da score bajo |
| `calcularScore_partialMatch_mediumScore` | Coincidencia parcial da score medio |
| `calcularScore_nullFields_handledGracefully` | Campos null no lanzan excepción |
| `calcularScore_fuzzyRaza_partialScore` | Coincidencia difusa de raza da puntaje parcial |
| `calcularScore_farDistance_zeroGeo` | Distancia lejana da score geográfico 0 |
| `superaUmbral_above_returnsTrue` | Score sobre umbral retorna true |
| `superaUmbral_below_returnsFalse` | Score bajo umbral retorna false |
| `superaUmbral_exact_returnsTrue` | Score exacto al umbral retorna true |
| `calcularScore_sameLocation_maxGeoScore` | Misma ubicación da score geográfico máximo |
| `calcularScore_containsMatch_80percent` | Coincidencia parcial de texto da 80% |

---

### ms-geolocalizacion — 5 tests

#### `ClusteringServiceTest.java` (5 tests) — Patrón: Pure Unit Test (DBSCAN)
| Test | Qué verifica |
|------|-------------|
| `runDBSCAN_insufficientPoints_doesNotCluster` | Pocos puntos no forman cluster |
| `runDBSCAN_closePoints_formCluster` | Puntos cercanos forman un cluster |
| `runDBSCAN_farPoints_noCluster` | Puntos lejanos no se agrupan |
| `runDBSCAN_mixedDistance_partialCluster` | Mezcla de distancias forma cluster parcial |
| `runDBSCAN_emptyList_doesNothing` | Lista vacía no hace nada |

---

## Resumen por módulo

| Módulo | Tests | Clases de test | Patrón principal |
|--------|-------|----------------|-----------------|
| auth-service | 31 | AuthServiceTest, JwtUtilsTest, AuthControllerTest | Mock Objects + Pure Unit |
| bff-service | 14 | AuthProxyServiceTest, JwtAuthFilterTest, GlobalExceptionHandlerTest | Mock Objects |
| ms-mascotas | 13 | ReporteFactoryTest, ReporteServiceTest | Factory + Mock Objects |
| ms-coincidencias | 19 | CoincidenciaServiceTest, ScoringServiceTest | Mock Objects + Pure Unit |
| ms-geolocalizacion | 5 | ClusteringServiceTest | Pure Unit (DBSCAN) |
| **TOTAL** | **77** | **9 clases** | |

---

## Para hacer fallar un test (demo en defensa)

Editar el test, cambiar una aserción y volver a correr:

```java
// Ejemplo en ReporteServiceTest.java — línea ~107
// Cambiar times(2) por times(3) → el test falla
verify(reporteRepository, times(3)).save(any(Reporte.class));
```

```powershell
# Correr solo ese test para ver el fallo
docker run --rm -v "c:\Users\LENOVO\sanos_y_salvos:/app" -w /app maven:3.9-eclipse-temurin-21-alpine mvn test -pl ms-mascotas --no-transfer-progress "-Dtest=ReporteServiceTest#crearReporte_conFoto_success"
```

Resultado esperado al fallar:
```
Wanted 3 times but was 2 times → TESTS FAILED
```

Revertir el cambio y volver a correr → pasa de nuevo.
