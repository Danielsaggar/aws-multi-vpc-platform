# Español

## AWS Multi-VPC Platform

Arquitectura de referencia en Terraform para **AWS ca-central-1**, con cuentas
DEV/PROD separadas, dos VPC conectadas mediante peering, aplicaciones EC2 privadas,
RDS, Redis, ALB con TLS y entrega de S3 privado mediante CloudFront OAC.

**Estado:** la configuración AWS y las pruebas locales están implementadas; no
se ha realizado ningún despliegue en AWS real. Consulta la [evidencia de validación](docs/VALIDATION_MATRIX.md)
y las [limitaciones](docs/LIMITATIONS.md). Las aplicaciones de prueba no son
aplicaciones de negocio para producción. Los workflows AWS están deshabilitados por defecto.

El aprovisionamiento local y las pruebas de protocolos de bases de datos pasaron.
El segundo plan conserva las diferencias de Floci conocidas y solo las acepta
si coinciden con firmas estrictas de atributos y reemplazos. Cualquier diferencia
inesperada falla la integración. La matriz detalla resultados y límites; el drift
conocido del emulador no es drift de AWS ni significa cero diferencias.

### Primeros pasos

- [Arquitectura](docs/ARCHITECTURE.md) y [fuente del diagrama](docs/diagrams/architecture.mmd)
- [Flujo local con Floci](docs/FLOCI.md)
- [Bootstrap de estado y OIDC](docs/BOOTSTRAP.md)
- [Controles de despliegue AWS](docs/DEPLOYMENT.md)
- [Supuestos de costos](docs/COSTS.md)
- [Trazabilidad del desafío](docs/REQUIREMENTS.md)

### Validación sin credenciales AWS

Instala Terraform 1.16.2, Python 3, AWS CLI v2 y Docker con Compose.

```sh
python scripts/validate.py all
python scripts/local.py capabilities --read-only
docker compose -p pmp-integration -f compose.floci.yml up -d --wait --wait-timeout 120
python scripts/local.py integration --environment dev --endpoint http://localhost:4567
python scripts/local.py assert-clean
docker compose -p pmp-integration -f compose.floci.yml down --volumes
```

La validación usa proveedores Terraform simulados. La integración usa credenciales
ficticias, endpoints locales explícitos y estado aislado. Floci en el puerto 4566
se reserva para consultas de solo lectura; la integración usa el puerto 4567.

### Estrategia de entornos

Las ramas de funcionalidad se integran por PR en develop (DEV); la promoción a
main selecciona PROD. Una raíz compone módulos reutilizables con tfvars por entorno.
PROD tiene ocho instancias EC2 y dos NAT gateways; DEV tiene cuatro y uno.
El despliegue requiere salidas del bootstrap, datos de cuenta/DNS/AMI y entornos
GitHub protegidos. Nunca incluyas estado ni secretos en el repositorio.

Cada aplicación frontsite, backoffice, webapi y gameapi tiene una EC2 en DEV y
dos réplicas distribuidas entre dos AZ en PROD. La tabla de costos del desafío
usa cuatro EC2 como referencia; PROD usa ocho intencionalmente para disponibilidad
multi-AZ por aplicación. Auto Scaling está fuera del alcance y no se implementa.

---

# English

## AWS Multi-VPC Platform

Terraform reference architecture targeting **AWS ca-central-1** with separate
DEV/PROD accounts, two peered VPCs, private EC2 applications, RDS, Redis, ALB TLS
and private S3 delivery through CloudFront OAC.

**Status:** AWS configuration and local tests are implemented; no real AWS
deployment has occurred. See [validation evidence](docs/VALIDATION_MATRIX.md)
and [limitations](docs/LIMITATIONS.md). Smoke applications are not production
business applications. AWS workflows are disabled by default.

Local provisioning and database protocol checks passed. The second plan retains
known Floci differences and accepts them only when strict attribute/replacement
signatures match. Any unexpected difference fails integration. See the matrix
for results and limits; known emulator drift is not AWS drift or zero differences.

### Start here

- [Architecture](docs/ARCHITECTURE.md) and [diagram source](docs/diagrams/architecture.mmd)
- [Local Floci workflow](docs/FLOCI.md)
- [State and OIDC bootstrap](docs/BOOTSTRAP.md)
- [AWS deployment gates](docs/DEPLOYMENT.md)
- [Cost assumptions](docs/COSTS.md)
- [Challenge traceability](docs/REQUIREMENTS.md)

### Validate without AWS credentials

Install Terraform 1.16.2, Python 3, AWS CLI v2 and Docker with Compose.

```sh
python scripts/validate.py all
python scripts/local.py capabilities --read-only
docker compose -p pmp-integration -f compose.floci.yml up -d --wait --wait-timeout 120
python scripts/local.py integration --environment dev --endpoint http://localhost:4567
python scripts/local.py assert-clean
docker compose -p pmp-integration -f compose.floci.yml down --volumes
```

Validation uses mocked Terraform providers. Integration uses fake credentials,
explicit local endpoints and isolated state. Existing Floci on port 4566 is
reserved for read-only probes; integration uses port 4567.

### Environment strategy

Feature branches merge by PR into develop (DEV); promotion to main selects PROD.
One root composes reusable modules with environment tfvars. PROD has eight EC2
instances and two NAT gateways; DEV has four and one. Deployment requires bootstrap outputs, account/DNS/AMI inputs and protected
GitHub environments. Never commit state or secrets.

Each of frontsite, backoffice, webapi and gameapi has one EC2 instance in DEV
and two replicas across two AZs in PROD. The challenge cost table uses four EC2
as a reference; PROD intentionally uses eight for per-workload multi-AZ availability.
Auto Scaling is outside challenge scope and is not implemented.
