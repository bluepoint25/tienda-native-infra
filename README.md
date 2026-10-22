# tienda-native-infra

Infraestructura como código (**Terraform**) y scripts de despliegue de **Tienda Native**
(DSY1107 · Desarrollo Cloud Native I), sobre el AWS Academy Learner Lab.

```
Amplify (React) ──JWT──► API Gateway ──► ms-productos  (ECS Fargate) ──► DynamoDB
      │                      │                 │ publica
      ▼                      │                 ▼
   Cognito                   │        EC2: docker compose · clúster RabbitMQ (3 nodos)
 (Hosted UI, grupos,         │                 │ consume
  Lambda de scopes)          └──────────► ms-mensajeria (ECS Fargate)
```

## Repositorios

| Repo | Contenido |
|---|---|
| [Tienda-native](https://github.com/bluepoint25/Tienda-native) | Frontend React (Vite) desplegado en Amplify |
| [ms-productos](https://github.com/bluepoint25/ms-productos) | CRUD, DynamoDB, productor de eventos |
| [ms-mensajeria](https://github.com/bluepoint25/ms-mensajeria) | Consumidores, DLQ, administrador de RabbitMQ y docker-compose del clúster |
| **tienda-native-infra** (este) | Terraform + `scripts/publicar-ecs.ps1` |

Terraform y `scripts/publicar-ecs.ps1` buscan los microservicios **dentro** de este repo, con estos nombres exactos de carpeta (están en el `.gitignore`):

```bash
git clone https://github.com/bluepoint25/tienda-native-infra.git tienda-native
cd tienda-native
git clone https://github.com/bluepoint25/ms-productos.git tienda-native-backend
git clone https://github.com/bluepoint25/ms-mensajeria.git ms-mensajeria
git clone https://github.com/bluepoint25/Tienda-native.git tienda-native-frontend
```

```
tienda-native/               (este repo)
├── terraform/  scripts/
├── tienda-native-backend/   (ms-productos)
├── ms-mensajeria/           (incluye rabbitmq-cluster/docker-compose.yml)
└── tienda-native-frontend/
```

El paso a paso completo, desde cero y para la presentación, está en [MANUAL.md](MANUAL.md).

## Módulos

| Módulo | Qué crea |
|---|---|
| `cognito` | User pool (tier ESSENTIALS), Hosted UI, app client OAuth2 code flow, resource server con `productos/read` y `productos/write`, grupos `editores` y `lectores`, usuarios de prueba y la Lambda *Pre Token Generation V2* que traduce grupo → scopes |
| `api-gateway` | HTTP API con JWT authorizer de Cognito y un scope exigido por ruta, hacia los dos microservicios |
| `dynamodb` | Tabla `tienda-native-productos` |
| `ecr` | Un repositorio de imágenes por microservicio |
| `ecs` | Clúster Fargate, una task definition y un servicio por microservicio (rol `LabRole`) |
| `rabbitmq` | EC2 `t3.medium` que en el arranque (`user_data`) instala Docker y ejecuta el docker-compose del clúster; usuario y contraseña generados con `random_password`; AMQP abierto solo al security group de ECS |
| `amplify` | App del front (importada) con la regla SPA y las variables `VITE_*` tomadas de los demás módulos |

## Usuarios de prueba

Terraform crea dos usuarios en Cognito. Sus contraseñas **temporales** se definen en `terraform.tfvars`, que no se versiona, y Cognito pide cambiarlas en el primer ingreso.

| Usuario | Variable con la contraseña temporal | Grupo | Puede |
|---|---|---|---|
| `test@tiendanative.com` | `test_user_password` | `editores` | consultar, crear, editar y eliminar (`productos/read` + `productos/write`) |
| `lector@tiendanative.com` | `lector_user_password` | `lectores` | solo consultar (`productos/read`) → crear da **403** |

Para entregar acceso a una cuenta ya desplegada, las credenciales se comparten por un canal privado, nunca en el repositorio ni en la app. Para recuperar el acceso de un usuario, se le asigna una contraseña temporal nueva:

```bash
aws cognito-idp admin-set-user-password --user-pool-id <pool> --username test@tiendanative.com --password '<nueva>' --no-permanent
```

## Uso

1. Copia el archivo de variables y complétalo:
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```
2. Pulsa **Start Lab** en AWS Academy y copia las credenciales en `~/.aws/credentials`.
3. Aplica la infraestructura:
   ```bash
   cd terraform
   terraform init
   terraform plan        # leer antes de aplicar
   terraform apply
   ```
4. Publica los dos microservicios y apunta el API Gateway a sus tasks:
   ```bash
   powershell -File scripts/publicar-ecs.ps1
   ```
   Con `-Solo productos` o `-Solo mensajeria` publicas solo uno.

### Después de cada Start Lab

- La EC2 de RabbitMQ se enciende sola y el clúster vuelve con `restart: always`. Su **IP privada no cambia**.
- Las tasks de ECS cambian de IP pública: vuelve a ejecutar `scripts/publicar-ecs.ps1`.
- La IP pública del dashboard también cambia:
  ```bash
  terraform apply -refresh-only
  terraform output rabbitmq_dashboard
  ```

### Datos útiles

```bash
terraform output amplify_url
terraform output rabbitmq_dashboard        # usuario: admin
terraform output -raw rabbitmq_password
```

Para ver el docker-compose en la nube: en la consola de EC2, `tienda-native-rabbitmq` → **Connect → Session Manager**, y ejecuta:

```bash
cd /opt/rabbitmq-cluster && sudo docker compose ps
```

## Seguridad

- `terraform.tfvars` y `terraform.tfstate*` **no se versionan**: contienen contraseñas e IDs reales.
- El dashboard de RabbitMQ solo se abre desde `admin_cidr`. AMQP solo se acepta desde las tasks de ECS.
- El puerto de los microservicios queda abierto porque el API Gateway (HTTP API) los llama por internet. La puerta real es el gateway, que valida el JWT y los scopes.
