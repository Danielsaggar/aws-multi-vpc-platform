# Español

## Flujo local con Floci

El endpoint del emulador para solo lectura es http://localhost:4566. Las consultas
usan credenciales ficticias y ca-central-1 explícito. Las pruebas de ciclo de vida
rechazan el puerto 4566 y usan un contenedor independiente en http://localhost:4567.

```sh
terraform init -backend=false -input=false
python scripts/local.py preflight
python scripts/local.py capabilities --read-only
docker compose -p pmp-integration -f compose.floci.yml up -d --wait --wait-timeout 120
python scripts/local.py bootstrap --environment dev --endpoint http://localhost:4567
python scripts/local.py integration --environment dev --endpoint http://localhost:4567
python scripts/local.py integration --environment prod --endpoint http://localhost:4567
python scripts/local.py assert-clean
docker compose -p pmp-integration -f compose.floci.yml down --volumes
```

El harness copia Terraform en .local/ENV, que está ignorado, adapta proveedor/backend
y los ajustes específicos del emulador enumerados abajo, usa credenciales ficticias,
desactiva descubrimiento de perfiles/metadatos y sustituye todos los endpoints.
Después aplica, verifica, comprueba drift y destruye en finally. Un proxy HTTP
local reenvía solo al puerto loopback elegido y rechaza hosts externos. Resuelve
el hostname localhost de S3 Control con prefijo de cuenta del SDK sin modificar
DNS/hosts. Las solicitudes HTTPS salientes están bloqueadas.
Los módulos de producción no tienen interruptores de modo local. Las ejecuciones
interrumpidas conservan estado para
`cleanup --owned-only --environment ENV --endpoint http://localhost:4567`.

Adaptaciones verificadas de Floci 2.1.0:

- Los identificadores AZ se transforman de cac1-azN a ca-central-1-azN del emulador.
- Una zona Route 53 local example.test sustituye la entrada de zona externa.
- ElastiCache CreateUserGroup no está soportado; se omiten recursos locales de
  usuarios/grupos y sus asociaciones de autenticación. Estas pruebas no certifican IAM/TLS.
- La limpieza local desactiva protección de eliminación RDS/ALB PROD y snapshots finales.
- Los secretos de aplicación vacíos se eliminan inmediatamente en local; AWS usa ventanas de recuperación.
- UserNotFoundFault de Floci difiere del error esperado por el proveedor. La
  limpieza elimina una entrada de usuario obsoleta del estado solo si la API demuestra su ausencia.

El acceso al socket Docker es necesario para cargas respaldadas por contenedores
y concede control considerable del host. Ejecuta CI en runners desechables. No
se ejecuta Docker prune, limpieza global, reemplazo del contenedor del usuario
ni descubrimiento de perfiles AWS. El soporte del proveedor es distinto de la
respuesta de las API; consulta la matriz.

El segundo plan acepta solo firmas conocidas de Floci 2.1.0: tipo, rutas de
atributos, valores observados y rutas de reemplazo deben coincidir. Los attachments
requieren además una referencia verificada a una EC2 con reemplazo conocido.
Ningún tipo de recurso se acepta de forma general. El drift conocido permanece
visible; cualquier diferencia inesperada falla. No es drift de AWS ni cero drift.
La limpieza se ejecuta igualmente. Ejecuta los comandos de ciclo de
vida de manera independiente si el shell se detiene ante un código distinto de
cero. Las pruebas PostgreSQL/Redis se ejecutan dentro de contenedores Docker y
no validan enrutamiento AWS, TLS ni cumplimiento IAM. Genera detalles saneados
desde el segundo plan local guardado con `python scripts/drift.py dev` o
`python scripts/drift.py prod`. Los informes `.local/` se generan localmente y
no se publican; consulta los [resultados de validación](VALIDATION_MATRIX.md).

El harness inicia su propio proyecto Compose pmp-integration y espera el healthcheck
con --wait; no depende del contenedor antiguo floci. El comando up mostrado es
opcional al usar el harness. CI ejecuta esta integración en pull_request y push
hacia develop/main, y mediante workflow_dispatch. AWS permanece deshabilitado.

---

# English

## Local Floci workflow

The read-only emulator endpoint is http://localhost:4566. Read-only probes use it
with fake credentials and explicit ca-central-1. Lifecycle tests refuse port
4566 and use an independently owned container at http://localhost:4567.

```sh
terraform init -backend=false -input=false
python scripts/local.py preflight
python scripts/local.py capabilities --read-only
docker compose -p pmp-integration -f compose.floci.yml up -d --wait --wait-timeout 120
python scripts/local.py bootstrap --environment dev --endpoint http://localhost:4567
python scripts/local.py integration --environment dev --endpoint http://localhost:4567
python scripts/local.py integration --environment prod --endpoint http://localhost:4567
python scripts/local.py assert-clean
docker compose -p pmp-integration -f compose.floci.yml down --volumes
```

The harness copies Terraform into ignored .local/ENV, adapts the provider/backend and the emulator-specific settings listed below,
uses fake credentials, disables profile/metadata discovery, overrides all service
endpoints, then applies, asserts, checks drift and destroys in finally.
A local HTTP proxy forwards only to the selected loopback port and rejects
external hosts. It resolves the SDK's account-prefixed S3 Control localhost name
without changing DNS/hosts files. HTTPS outbound requests are blocked.
Production source modules have no local-mode switches. Interrupted runs retain
state for `cleanup --owned-only --environment ENV --endpoint http://localhost:4567`.

Measured Floci 2.1.0 adaptations:

- AZ IDs map cac1-azN to the emulator's ca-central-1-azN.
- A local example.test Route 53 zone replaces the external hosted-zone input.
- ElastiCache CreateUserGroup is unsupported; local user/group resources are
  skipped and replication-group authentication bindings omitted. IAM/TLS security
  is therefore not certified by these local tests.
- Local disposal disables RDS/ALB PROD deletion protection and final snapshots.
- Empty application secrets use immediate local deletion; AWS uses recovery windows.
- Floci's UserNotFoundFault differs from the provider's expected error. Cleanup
  removes a stale user state entry only after the API explicitly proves absence.

Docker socket access is necessary for supported container-backed workloads and
grants substantial host control. Run CI on disposable runners. No Docker prune,
global cleanup, user-container replacement or AWS profile discovery is performed.
Provider support and service API responsiveness are distinct; consult the matrix.

The second plan accepts only known Floci 2.1.0 signatures: type, attribute paths,
observed values and replacement paths must match. Attachments also require a
verified reference to an EC2 instance with a known replacement. No resource type
is accepted wholesale. Known drift stays visible; any unexpected difference
fails. This is neither AWS drift nor zero drift. Cleanup still runs.
Execute lifecycle commands independently if the shell
stops on a nonzero exit. PostgreSQL/Redis checks execute inside Docker containers
and do not validate AWS routing, TLS or IAM enforcement. Generate sanitized
details from a saved local second plan with `python scripts/drift.py dev` or
`python scripts/drift.py prod`. `.local/` reports are generated locally, not
published artifacts; see [validation results](VALIDATION_MATRIX.md).

The harness starts its own pmp-integration Compose project and waits for the
healthcheck using --wait; it does not depend on the old floci container. The up
command shown is optional when using the harness. CI runs this integration on
pull_request and push to develop/main, and workflow_dispatch. AWS remains disabled.
