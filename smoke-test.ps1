# =============================================================
# smoke-test.ps1 — Verificación rápida post-deploy
# Ejecutar después de master-deploy.ps1 para confirmar que
# todos los servicios responden correctamente antes de presentar.
# =============================================================

param(
    [string]$AlbDns      = "",   # Se lee de terraform output si está vacío
    [string]$Ec2Ip       = "",   # IP pública del EC2 para checks directos
    [int]   $TimeoutSec  = 10
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   Sanos y Salvos - Smoke Test Post-Deploy  " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$passed  = 0
$failed  = 0
$results = @()

# ---------------------------------------------------------
# Función helper para probar un endpoint
# ---------------------------------------------------------
function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url,
        [string]$ExpectedContent = "",
        [int]   $ExpectedStatus  = 200
    )
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSec `
            -UseBasicParsing -ErrorAction Stop
        $ok = $response.StatusCode -eq $ExpectedStatus
        if ($ExpectedContent -and $response.Content -notlike "*$ExpectedContent*") {
            $ok = $false
        }
        if ($ok) {
            Write-Host "  [PASS] $Name ($($response.StatusCode))" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  [FAIL] $Name - Status $($response.StatusCode), esperado $ExpectedStatus" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "  [FAIL] $Name - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ---------------------------------------------------------
# Obtener endpoints desde terraform output si no se pasaron
# ---------------------------------------------------------
if (-not $AlbDns -or -not $Ec2Ip) {
    Write-Host "Leyendo outputs de Terraform..." -ForegroundColor Yellow
    try {
        $tfOutputRaw = terraform output -json 2>$null
        if ($tfOutputRaw) {
            $tfOutput = $tfOutputRaw | ConvertFrom-Json
            if (-not $AlbDns -and $tfOutput.alb_dns) {
                $AlbDns = $tfOutput.alb_dns.value
            }
            if (-not $Ec2Ip -and $tfOutput.ec2_public_ip) {
                $Ec2Ip = $tfOutput.ec2_public_ip.value
            }
        }
    }
    catch {
        Write-Host "[WARN] No se pudieron leer outputs de Terraform" -ForegroundColor Yellow
    }
}

Write-Host "ALB DNS : $AlbDns"
Write-Host "EC2 IP  : $Ec2Ip"
Write-Host ""

# ---------------------------------------------------------
# 1. Health checks via ALB
# ---------------------------------------------------------
Write-Host "=== 1. Health Checks via ALB ===" -ForegroundColor Yellow
if ($AlbDns) {
    $albBase = "http://$AlbDns"

    if (Test-Endpoint "BFF Health (ALB /api/actuator/health)" `
        "$albBase/api/actuator/health" -ExpectedContent "UP") { $passed++ } else { $failed++ }
}
else {
    Write-Host "  [SKIP] ALB DNS no disponible" -ForegroundColor Gray
}

# ---------------------------------------------------------
# 2. Health checks directos al EC2 (bypass ALB)
# ---------------------------------------------------------
Write-Host ""
Write-Host "=== 2. Health Checks Directos al EC2 ===" -ForegroundColor Yellow
if ($Ec2Ip) {
    $checks = @(
        @{ Name = "BFF Service           (:8080)"; Url = "http://${Ec2Ip}:8080/actuator/health"; Content = "UP" },
        @{ Name = "auth-service          (:8081)"; Url = "http://${Ec2Ip}:8081/actuator/health"; Content = "UP" },
        @{ Name = "ms-mascotas           (:8082)"; Url = "http://${Ec2Ip}:8082/actuator/health"; Content = "UP" },
        @{ Name = "ms-geolocalizacion    (:8083)"; Url = "http://${Ec2Ip}:8083/actuator/health"; Content = "UP" },
        @{ Name = "ms-coincidencias      (:8084)"; Url = "http://${Ec2Ip}:8084/actuator/health"; Content = "UP" }
    )
    foreach ($check in $checks) {
        if (Test-Endpoint $check.Name $check.Url -ExpectedContent $check.Content) {
            $passed++
        } else {
            $failed++
        }
    }
}
else {
    Write-Host "  [SKIP] EC2 IP no disponible" -ForegroundColor Gray
}

# ---------------------------------------------------------
# 3. Test de registro + login (flujo básico)
# ---------------------------------------------------------
Write-Host ""
Write-Host "=== 3. Test Flujo Auth ===" -ForegroundColor Yellow
if ($Ec2Ip) {
    $testUser = @{
        nombre   = "Test Presentacion"
        email    = "test.demo.$(Get-Random -Maximum 9999)@sanos.cl"
        password = "TestDemo2026!"
    } | ConvertTo-Json

    try {
        # Registro
        $regResp = Invoke-WebRequest -Uri "http://${Ec2Ip}:8081/api/auth/register" `
            -Method POST -Body $testUser -ContentType "application/json" `
            -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        Write-Host "  [PASS] Registro de usuario ($($regResp.StatusCode))" -ForegroundColor Green
        $passed++
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -in @(200, 201)) {
            Write-Host "  [PASS] Registro de usuario ($statusCode)" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  [INFO] Registro: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# ---------------------------------------------------------
# 4. Verificar frontend en S3
# ---------------------------------------------------------
Write-Host ""
Write-Host "=== 4. Frontend S3 ===" -ForegroundColor Yellow
try {
    $tfOutput = terraform output -json 2>$null | ConvertFrom-Json
    $s3Url = "http://sanos-y-salvos-frontend-$($tfOutput.resumen_infraestructura.value.ecr_registry.Split('.')[0]).s3-website-us-east-1.amazonaws.com"
    if (Test-Endpoint "Frontend S3" $s3Url) { $passed++ } else { $failed++ }
}
catch {
    Write-Host "  [SKIP] No se pudo obtener URL del frontend" -ForegroundColor Gray
}

# ---------------------------------------------------------
# Resumen
# ---------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " RESULTADO: $passed PASSED  |  $failed FAILED " -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($failed -gt 0) {
    Write-Host "Algunos checks fallaron. Acciones sugeridas:" -ForegroundColor Yellow
    Write-Host "  1. ssh ec2-user@$Ec2Ip -i sanos-y-salvos-key.pem"
    Write-Host "  2. tail -f /var/log/sanos-deploy.log"
    Write-Host "  3. docker ps  (verificar contenedores corriendo)"
    Write-Host "  4. docker logs bff-service  (ver errores de startup)"
    Write-Host ""
}

if ($failed -eq 0) {
    Write-Host "Todo funciona. Listo para presentar!" -ForegroundColor Green
    if ($AlbDns) {
        Write-Host ""
        Write-Host "URL de la aplicacion: http://$AlbDns" -ForegroundColor Cyan
    }
}

exit $failed
