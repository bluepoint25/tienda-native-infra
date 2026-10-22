# Publica ms-productos y ms-mensajeria en ECS y reapunta el API Gateway a la IP de cada task.
# Uso: powershell -File scripts\publicar-ecs.ps1 [-Solo productos|mensajeria]
param(
    [ValidateSet("todos", "productos", "mensajeria")]
    [string]$Solo = "todos"
)

# PowerShell 5.1 trata el stderr de docker/mvn como error; los fallos se detectan con $LASTEXITCODE
$ErrorActionPreference = "Continue"
$root = Split-Path $PSScriptRoot -Parent
$region = "us-east-1"

function Tf($name) { terraform -chdir="$root\terraform" output -raw $name }
function Fallar($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

$cluster = Tf ecs_cluster_name
$apiId   = Tf api_gateway_id
$integ   = terraform -chdir="$root\terraform" output -json api_integration_ids | ConvertFrom-Json

$servicios = @(
    @{ Id = "productos";  Dir = "tienda-native-backend"; Repo = (Tf ecr_repository_url); Servicio = (Tf ecs_service_name); Puerto = 8080
       Integraciones = @(@{ Id = $integ.productos; Ruta = "/api/v1/productos" }, @{ Id = $integ.productos_item; Ruta = "/api/v1/productos/{proxy}" }) },
    @{ Id = "mensajeria"; Dir = "ms-mensajeria"; Repo = (Tf ecr_mensajeria_url); Servicio = (Tf ecs_mensajeria_service_name); Puerto = 8081
       Integraciones = @(@{ Id = $integ.mensajeria_eventos; Ruta = "/api/v1/eventos" }, @{ Id = $integ.mensajeria_admin; Ruta = "/api/v1/admin/{proxy}" }) }
) | Where-Object { $Solo -eq "todos" -or $_.Id -eq $Solo }

Write-Host "==> Autenticando contra ECR"
$registry = $servicios[0].Repo.Split("/")[0]
# El pipe de PowerShell 5.1 altera la contraseña (400 Bad Request); cmd la pasa intacta
cmd /c "aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $registry"
if ($LASTEXITCODE) { Fallar "docker login" }

foreach ($s in $servicios) {
    Write-Host "==> [$($s.Id)] Construyendo el jar y la imagen (linux/amd64)"
    Push-Location "$root\$($s.Dir)"
    mvn -q -DskipTests package
    if ($LASTEXITCODE) { Pop-Location; Fallar "mvn package de $($s.Id)" }
    docker build --platform linux/amd64 -t "$($s.Repo):latest" .
    if ($LASTEXITCODE) { Pop-Location; Fallar "docker build de $($s.Id)" }
    Pop-Location

    Write-Host "==> [$($s.Id)] Subiendo la imagen"
    docker push "$($s.Repo):latest"
    if ($LASTEXITCODE) { Fallar "docker push de $($s.Id)" }

    Write-Host "==> [$($s.Id)] Redesplegando con la última task definition"
    $family = aws ecs describe-services --cluster $cluster --services $s.Servicio --region $region `
      --query "services[0].taskDefinition" --output text
    $family = ($family -split "/")[-1] -replace ":\d+$", ""
    aws ecs update-service --cluster $cluster --service $s.Servicio --task-definition $family `
      --force-new-deployment --region $region --output text --query "service.serviceName" | Out-Null
}

foreach ($s in $servicios) {
    Write-Host "==> [$($s.Id)] Esperando la task nueva"
    aws ecs wait services-stable --cluster $cluster --services $s.Servicio --region $region

    $taskArn = aws ecs list-tasks --cluster $cluster --service-name $s.Servicio --desired-status RUNNING `
      --region $region --query "taskArns[0]" --output text
    $eni = aws ecs describe-tasks --cluster $cluster --tasks $taskArn --region $region `
      --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text
    $ip = aws ec2 describe-network-interfaces --network-interface-ids $eni --region $region `
      --query "NetworkInterfaces[0].Association.PublicIp" --output text
    Write-Host "    Task RUNNING con IP pública $ip"

    foreach ($i in $s.Integraciones) {
        aws apigatewayv2 update-integration --api-id $apiId --integration-id $i.Id `
          --integration-uri "http://${ip}:$($s.Puerto)$($i.Ruta)" --region $region --output text --query "IntegrationUri"
    }
}

Write-Host "Listo: $(Tf productos_api_url)"
