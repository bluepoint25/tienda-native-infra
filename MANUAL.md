# Manual de Tienda Native

**DSY1107 · Desarrollo Cloud Native I** — cómo levantar el sistema desde cero, cómo retomarlo después de cada sesión del laboratorio y cómo presentarlo.

---

## 0. Qué es

Tienda Native es una tienda de productos cloud native sobre AWS (Learner Lab). Tiene:

- un **frontend React** con login OAuth 2.0 / OIDC;
- un **API Manager** (API Gateway) que valida el JWT;
- dos **microservicios Spring Boot** que se comunican por **RabbitMQ**.

Toda la infraestructura está declarada en **Terraform**.

```
Amplify (React) ──JWT──► API Gateway ──► ms-productos  (ECS Fargate) ──► DynamoDB
      │              (JWT authorizer)          │ publica eventos
      ▼                     │                  ▼
   Cognito                  │        EC2: docker compose · clúster RabbitMQ (3 nodos)
 (IDaaS: Hosted UI,         │                  │ consume
  grupos, Lambda)           └──────────► ms-mensajeria (ECS Fargate)
```

| Repositorio | Qué contiene |
|---|---|
| [tienda-native-infra](https://github.com/bluepoint25/tienda-native-infra) | Terraform, script de despliegue y este manual |
| [ms-productos](https://github.com/bluepoint25/ms-productos) | CRUD de productos, DynamoDB, validación JWT, **productor** de eventos |
| [ms-mensajeria](https://github.com/bluepoint25/ms-mensajeria) | **Consumidores** por dominio, ACK manual, DLQ, **administrador REST de RabbitMQ** y `docker-compose` del clúster |
| [Tienda-native](https://github.com/bluepoint25/Tienda-native) | Frontend React + Vite (desplegado en Amplify) |

### Mensajería

| Exchange (tipo) | Routing key | Cola | DLQ |
|---|---|---|---|
| `productos.direct.exchange` (**direct**) | `producto.creado` · `producto.actualizado` · `producto.eliminado` · `stock.bajo` | `auditoria.queue` | `auditoria.dlq` |
| `productos.direct.exchange` (**direct**) | `stock.bajo` | `inventario.queue` | `inventario.dlq` |
| `notificaciones.topic.exchange` (**topic**) | `notificacion.#` | `notificaciones.queue` | `notificaciones.dlq` |

- Las colas son **quorum**, replicadas en los 3 nodos.
- Los mensajes que fallan pasan por `mensajeria.dlx` a la DLQ de su cola, que los retiene 24 h.
- Decisión de ACK en cada consumidor:

| Resultado | Decisión |
|---|---|
| Procesado | `basicAck` |
| Error transitorio | `basicNack(requeue=true)`, hasta 3 intentos |
| Error permanente o intentos agotados | `basicNack(requeue=false)` → DLQ |

Para la demo hay dos fallas simuladas:
- un producto con **FALLA** en el nombre es un error transitorio: se reintenta y termina en la DLQ;
- un producto con **INVALIDO** en el nombre es un error permanente: va directo a la DLQ.

### Usuarios de prueba (Cognito)

| Usuario | Grupo | Scopes en el token | Puede |
|---|---|---|---|
| `test@tiendanative.com` | `editores` | `productos/read` `productos/write` | todo |
| `lector@tiendanative.com` | `lectores` | `productos/read` | solo ver; crear da **403** |

Las contraseñas **temporales** se definen en `terraform/terraform.tfvars`. Cognito pide cambiarlas en el primer ingreso. Nunca se escriben en el repo ni en la app.

---

## 1. Requisitos (una sola vez)

Probado en **Windows 11 con PowerShell 5.1**: el script de despliegue es `.ps1`.

| Herramienta | Versión | Verificar |
|---|---|---|
| Git | cualquiera | `git --version` |
| AWS CLI | v2 | `aws --version` |
| Terraform | ≥ 1.5 | `terraform version` |
| Java (JDK) | ≥ 17 | `java -version` |
| Maven | ≥ 3.9 | `mvn -v` |
| Node.js | ≥ 20 | `node -v` |
| Docker Desktop | encendido | `docker info` |

También necesitas:
- una cuenta de **AWS Academy Learner Lab**;
- una cuenta de **GitHub**, solo si levantas todo desde cero (parte A).

---

## Parte A · Levantar todo desde cero (cuenta nueva)

Calcula unos **30 minutos**. Si ya está desplegado en tu cuenta, salta a la **parte B**.

### A1. Clonar los repositorios

Terraform y el script buscan los microservicios **dentro** de la carpeta de infraestructura, con estos nombres exactos:

```bash
git clone https://github.com/bluepoint25/tienda-native-infra.git tienda-native
cd tienda-native
git clone https://github.com/bluepoint25/ms-productos.git tienda-native-backend
git clone https://github.com/bluepoint25/ms-mensajeria.git ms-mensajeria
git clone https://github.com/bluepoint25/Tienda-native.git tienda-native-frontend
```

### A2. Preparar el frontend en GitHub

Amplify compila el frontend desde un repositorio de GitHub y necesita un **token** para conectarse a él.

1. En GitHub, haz un **fork** de `bluepoint25/Tienda-native`.
2. Crea un token en **GitHub → Settings → Developer settings → Personal access tokens (classic)**, con el permiso `repo`.

### A3. Iniciar el laboratorio y cargar credenciales

1. En AWS Academy pulsa **Start Lab** y espera a que el punto se ponga **verde**.
2. Ve a **AWS Details → AWS CLI: Show** y copia el bloque completo en `%USERPROFILE%\.aws\credentials`.
3. Verifica la conexión (debe mostrar tu número de cuenta):
```bash
aws sts get-caller-identity
```

### A4. Completar las variables

```bash
copy terraform\terraform.tfvars.example terraform\terraform.tfvars
```

Abre `terraform\terraform.tfvars` y completa cada valor. Estos comandos te dan los datos:

```bash
aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text
```
```bash
aws ec2 describe-subnets --filters Name=vpc-id,Values=<VPC_ID> Name=map-public-ip-on-launch,Values=true --query "Subnets[].SubnetId"
```
```bash
curl https://checkip.amazonaws.com
```

| Variable | Valor |
|---|---|
| `vpc_id` | resultado del primer comando |
| `subnet_ids` | dos o más del segundo comando |
| `admin_cidr` | tu IP + `/32`, por ejemplo `186.189.97.29/32` |
| `frontend_repository` | la URL de tu fork |
| `github_access_token` | el token del paso A2 |
| `test_user_password`, `lector_user_password` | contraseñas temporales: 8+ caracteres, con mayúscula, minúscula, número y símbolo |

> **Trampa del lab:** la VPC por defecto a veces no trae la ruta a internet. Si este comando **no** muestra `0.0.0.0/0` con un `igw-…`, las tasks de ECS no podrán bajar su imagen. Agrega la ruta en **VPC → Route tables**: `0.0.0.0/0` → el internet gateway.
> ```bash
> aws ec2 describe-route-tables --filters Name=vpc-id,Values=<VPC_ID> --query "RouteTables[].Routes[].[DestinationCidrBlock,GatewayId]" --output text
> ```

### A5. Crear la infraestructura

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

- **Lee el `plan`** antes de confirmar: en una cuenta nueva solo debe haber recursos *to add*.
- El `apply` tarda de 5 a 10 minutos.
- Es normal que los servicios de ECS queden reintentando con el error `CannotPullContainerError`: todavía no existen las imágenes, se publican en el paso A6.
- La EC2 levanta el clúster de RabbitMQ sola en unos 3 minutos, ejecutando `docker compose up -d` en su arranque.

### A6. Publicar los dos microservicios

Con **Docker Desktop encendido**, desde la carpeta `tienda-native`:

```bash
powershell -ExecutionPolicy Bypass -File scripts\publicar-ecs.ps1
```

El script hace todo esto (tarda de 5 a 8 minutos):
1. Compila los dos microservicios.
2. Construye las imágenes `linux/amd64` y las sube a ECR.
3. Redespliega los dos servicios de ECS.
4. Apunta las 4 integraciones del API Gateway a la IP de cada task.

Termina con `Listo: https://…/dev/api/v1/productos`.

### A7. Primera compilación del frontend

La primera compilación de Amplify hay que lanzarla a mano; las siguientes son automáticas en cada push:

```bash
cd terraform
terraform output -raw amplify_app_id
aws amplify start-job --app-id <APP_ID> --branch-name main --job-type RELEASE
```

Espera a que la consola de **Amplify** muestre **Implementación realizada** (unos 3 minutos).

### A8. Comprobar

```bash
terraform output amplify_url
```

1. Abre esa URL y pulsa **Ingresar con Cognito**.
2. Entra con `test@tiendanative.com` y la contraseña temporal; Cognito pedirá una nueva.
3. Crea un producto y abre la pestaña **🔔 Eventos**: debe aparecer como **Auditado**.

Si todo eso funciona, el sistema está completo.

---

## Parte B · Retomar el entorno después de cada Start Lab

Esta es la rutina antes de cada demo, en una cuenta donde ya está desplegado. Calcula unos **10 minutos**.

1. Pulsa **Start Lab** y copia las credenciales nuevas en `%USERPROFILE%\.aws\credentials` (como en el paso A3).
2. Si cambiaste de red, por ejemplo en DUOC, actualiza tu IP:
   ```bash
   curl https://checkip.amazonaws.com
   ```
   Pon el resultado + `/32` en `admin_cidr` dentro de `terraform\terraform.tfvars`.
3. Sincroniza Terraform con las IP nuevas de la EC2. Cuando la sesión del lab se cierra, la EC2 se apaga y al volver cambia su IP **pública**; la privada se mantiene.
   ```bash
   cd terraform
   terraform apply
   ```
   Lee el `plan`: solo debe cambiar el security group, si cambió tu IP.
4. Comprueba que el clúster de RabbitMQ esté arriba. Se enciende solo gracias a `restart: always`:
   ```bash
   terraform output rabbitmq_dashboard
   ```
   Abre esa URL. El usuario es `admin` y la contraseña sale con:
   ```bash
   terraform output -raw rabbitmq_password
   ```
   En la pestaña **Overview** deben verse 3 nodos en verde.
5. Republica los microservicios: las tasks de ECS cambian de IP en cada sesión. Con **Docker Desktop encendido**:
   ```bash
   powershell -ExecutionPolicy Bypass -File ..\scripts\publicar-ecs.ps1
   ```
6. Abre la app (`terraform output amplify_url`) con **Ctrl+Shift+R**.

---

## Parte C · Guion de la presentación (EP4, 5 a 10 minutos)

Antes de empezar:
- deja abiertas estas pestañas: la app, el dashboard de RabbitMQ, la consola de AWS y una terminal;
- entra a la app como **editor**.

Cada punto corresponde a un requisito de la pauta.

### 1. Diseño y tecnologías (1 min)

Muestra el diagrama de la sección 0 y explica:
- Son **dos microservicios** Spring Boot que **no se llaman entre sí**: se comunican solo por RabbitMQ.
- El **API Gateway** es la única puerta y valida el JWT.
- Cognito es el **IDaaS**. Una Lambda pone los permisos en el token según el grupo del usuario.
- Todo está en **Terraform**: lo crea un solo `terraform apply`.

### 2. API Manager creado y configurado

**Consola → API Gateway → `tienda-native-api`.** Muestra:
- **Routes:** cada ruta tiene el authorizer `cognito-jwt` y su scope (`productos/read` o `productos/write`).
- **Integrations:** cada integración apunta a la IP de una task de ECS: `:8080` es ms-productos y `:8081` es ms-mensajeria.
- **Authorizers:** el issuer es el user pool y la audiencia es el client id.

### 3. El API Manager valida el JWT: rechaza los inválidos y acepta los válidos

En la terminal, primero sin token y con un token falso. Ambos deben dar **401 Unauthorized**, y la petición nunca llega al backend:

```bash
curl -i https://<API>/dev/api/v1/productos
```
```bash
curl -i -H "Authorization: Bearer token.falso.123" https://<API>/dev/api/v1/productos
```

Luego con un token válido:
1. En la app abre **F12 → Application → Local Storage** y copia `access_token`.
2. Pégalo en **jwt.io** y muestra el claim `scope`, que contiene `productos/read productos/write`.
3. Llama al API con ese token; debe responder **200** con la lista de productos:
```bash
curl -i -H "Authorization: Bearer <access_token>" https://<API>/dev/api/v1/productos
```

`<API>` sale de `terraform output api_gateway_endpoint`.

### 4. Tenant IDaaS y usuarios registrados

**Consola → Cognito → `tienda-native-user-pool`:**
- **Users:** están los 2 usuarios.
- **Groups:** `editores` y `lectores`.
- **App clients:** OAuth `code` y los scopes `openid email profile`.
- **Domain:** el Hosted UI.
- **Extensions:** la Lambda *Pre Token Generation V2*.

### 5. El frontend usa OAuth 2.0 / OIDC

1. Haz **Logout**: cierra también la sesión del Hosted UI.
2. Pulsa **Ingresar con Cognito**. Te redirige a `…amazoncognito.com/oauth2/authorize` (flujo *authorization code*).
3. Al volver, el front canjea el `code` por los tokens.
4. **Autorización por rol:** entra como `lector@tiendanative.com` e intenta crear un producto. Debe dar **403**: el token es válido pero no trae `productos/write`. Vuelve a entrar como editor.

### 6. Back y front desplegados en la nube, activos e integrados

- **Consola → ECS → `tienda-native-cluster`:** los 2 servicios (`tienda-native-service` y `tienda-native-mensajeria-service`) con 1 task **RUNNING** cada uno.
- **Consola → Amplify:** la rama `main` desplegada.
- En la app, crea el producto **"Teclado"** con stock **10**. Aparece en el catálogo, guardado en DynamoDB.

### 7. Dos nodos RabbitMQ en clúster (hay 3)

En el dashboard, pestaña **Overview → Nodes**, se ven `rabbit@rabbitmq-1`, `-2` y `-3` en verde.

Explica por qué son 3: las colas **quorum** necesitan mayoría (2 de 3). Con 2 nodos, al caer uno las colas dejarían de funcionar.

**Demostración opcional de caída de un nodo**, por Session Manager (punto 8):
1. Ejecuta `sudo docker stop rabbitmq-2`.
2. Crea un producto: se sigue procesando.
3. Ejecuta `sudo docker start rabbitmq-2`.

### 8. docker-compose ejecutándose en la nube

**Consola → EC2 → instancia `tienda-native-rabbitmq` → Connect → Session Manager → Connect.** Ejecuta:

```bash
cd /opt/rabbitmq-cluster
sudo docker compose ps
cat docker-compose.yml
```

Muestra los 3 contenedores `Up (healthy)`. Explica que es **el mismo `docker-compose.yml`** del repo ms-mensajeria: Terraform lo copia a la EC2 al crearla (`user_data`).

### 9. Exchanges direct y topic

En el dashboard, pestaña **Exchanges**:
- `productos.direct.exchange` es **direct**: entrega por routing key exacta.
- `notificaciones.topic.exchange` es **topic**: entrega por patrón, `notificacion.#`.
- `mensajeria.dlx` es el **dead letter exchange**.

Haz clic en `productos.direct.exchange` para mostrar sus **bindings**: auditoría recibe los 4 eventos, inventario solo `stock.bajo`.

### 10. Tres colas con su DLQ funcionando

En la pestaña **Queues** están las 3 colas y sus 3 DLQ, de tipo **quorum** y con la característica **DLX**. Luego, en la app, pestaña **🔔 Eventos**:

1. **Camino feliz con topic:** crea **"Silla"** con stock **2**. En el panel aparece:
   - `✓ Auditado`;
   - `⚠ Alerta stock` (inventario);
   - `✉ Notificación` (inventario publicó en el exchange topic y el consumidor de notificaciones la recibió).
2. **Reintentos y DLQ:**
   - En el panel, **detén** el consumidor `dlq`, para que el mensaje quede visible en la DLQ.
   - Crea **"Mesa FALLA"**. El panel muestra `↻ Reintento 1/3`, `2/3` y luego nada más: al tercer intento se mandó a la DLQ.
   - En el dashboard: **Queues → `auditoria.dlq` → Get messages**. Se ve el mensaje y su header `x-death` con `reason: rejected` y la cola de origen.
   - Vuelve a **iniciar** el consumidor `dlq`: lo registra en el log y aparece `✗ En DLQ` en el panel.
3. **Error permanente:** crea **"Cable INVALIDO"**. Va directo a la DLQ, sin reintentos.
4. **Desacoplamiento**, la idea central de la evaluación:
   - **Detén** el consumidor `auditoria`.
   - Crea un producto: la tienda funciona igual y en la tabla `auditoria.queue` muestra **1 mensaje en espera**.
   - **Inícialo** de nuevo: el mensaje se procesa al instante.

### 11. Administrador de RabbitMQ (EP3)

En el panel, sección **Administrar RabbitMQ**:
1. Crea la cola `pagos.queue` (QUORUM, con DLQ). Aparece en el dashboard junto con `pagos.queue.dlq`.
2. Crea el exchange `pagos.exchange` (TOPIC).
3. Crea el binding `pagos.queue` ← `pagos.exchange` con `pago.#`.
4. Muestra las validaciones:
   - una cola con nombre vacío da **400** con el mensaje del campo;
   - intentar eliminar `auditoria.queue` da **409**, porque es parte del sistema.
5. Elimina lo que creaste.

### 12. Código (si el profe lo pide)

En **ms-mensajeria**:

| Qué mostrar | Archivo |
|---|---|
| Nombres centralizados | `application.yml`, bloque `mensajeria` |
| Beans Queue / Exchange / Binding por caso de uso | `config/RabbitTopologyConfig` |
| Decisión de ACK y NACK | `common/MensajeAck` |
| Consumidores por dominio | `auditoria/`, `inventario/`, `notificaciones/`, `dlq/` |
| Administrador | `admin/RabbitAdminService`, `RabbitAdminController` y `dto/` con validaciones |
| Pruebas | `mvn test`: 17 pruebas |

---

## Parte D · Ejecutar en local (opcional)

Útil para desarrollar sin desplegar. Requiere credenciales del lab vigentes, porque ms-productos usa DynamoDB real.

1. Levanta el clúster de RabbitMQ en local:
   ```bash
   cd ms-mensajeria\rabbitmq-cluster
   docker compose up -d
   ```
   Dashboard: http://localhost:15672 (guest/guest).
2. Ejecuta `mvn spring-boot:run` en `ms-mensajeria` (puerto 8081) y en `tienda-native-backend` (puerto 8080).
3. Crea `tienda-native-frontend\.env.development.local` con:
   ```
   VITE_API_BASE_URL=http://localhost:8080
   VITE_MENSAJERIA_URL=http://localhost:8081
   VITE_COGNITO_REDIRECT_URI=http://localhost:5173/callback
   VITE_COGNITO_USER_POOL_ID=<terraform output -raw cognito_user_pool_id>
   VITE_COGNITO_CLIENT_ID=<terraform output -raw cognito_client_id>
   ```
4. Levanta el frontend con `npm install` y `npm run dev` en `tienda-native-frontend`, y abre http://localhost:5173.

---

## Parte E · Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `ExpiredToken` o `AccessDenied ... voc-cancel-cred` en cualquier comando `aws` o `terraform` | La sesión del lab expiró (dura unas 4 h) | **Start Lab** y credenciales nuevas |
| La app muestra **503** | El API Gateway apunta a una IP vieja de ECS | `scripts\publicar-ecs.ps1` |
| **401** con la sesión iniciada | El token expiró (1 h) | Logout y volver a entrar |
| **403** al crear un producto | El usuario está en `lectores`, o el token se emitió antes de cambiarlo de grupo | Entrar como editor, o hacer Logout y volver a entrar |
| El dashboard de RabbitMQ no carga | Tu IP cambió (`admin_cidr`) o la EC2 está apagada | Parte B, pasos 2 y 3 |
| El panel 🔔 Eventos muestra un error | ms-mensajeria no está corriendo, o está con la IP vieja | `scripts\publicar-ecs.ps1 -Solo mensajeria` |
| `CannotPullContainerError` en ECS | No se publicó la imagen, o falta la ruta `0.0.0.0/0` | Paso A6, y la trampa del paso A4 |
| `redirect_mismatch` al iniciar sesión | La URL del front no está en los callbacks de Cognito | `terraform apply`: Terraform toma la URL de Amplify |
| Docker Desktop: *"An unexpected error occurred"* | Archivos de socket colgados de una ejecución anterior | **Quit**, cerrar los procesos de Docker en el Administrador de tareas y volver a abrirlo. **No** usar *Reset to factory defaults* |
| `terraform apply` falla con `t3.medium is not supported in ... us-east-1e` | Ninguna subred está en una zona con `t3.medium` | Agregar en `subnet_ids` una subred de otra zona (a, b, c, d o f) |

Para ver los logs de los microservicios:

```bash
aws logs tail /ecs/tienda-native-backend --since 10m --follow
```
```bash
aws logs tail /ecs/tienda-native-mensajeria --since 10m --follow
```

---

## Parte F · Al terminar el semestre

Para borrar todo y no consumir el presupuesto del lab (la EC2 `t3.medium` es lo que más cuesta):

```bash
cd terraform
terraform destroy
```

Esto elimina también la app de Amplify, el user pool con sus usuarios y la tabla de DynamoDB con sus productos.
