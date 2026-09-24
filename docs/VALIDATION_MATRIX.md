# Español

## Matriz de validación

Evidencia local registrada el 2026-09-24: Terraform 1.16.2, proveedor AWS 6.66.0,
Floci 2.1.0 fijado por digest. No se realizaron operaciones en AWS real.

| Área | Evidencia obtenida | Límites pendientes |
| --- | --- | --- |
| Terraform | Raíz/bootstrap validados; nueve pruebas simuladas de raíz y una de bootstrap aprobadas | No es evidencia de despliegue AWS |
| Harness y controles de despliegue | Diecinueve pruebas Python de seguridad/diagnóstico aprobadas | Las protecciones de entornos GitHub requieren configuración |
| Análisis estático | TFLint, actionlint y Gitleaks pasaron localmente | No es una auditoría completa de seguridad |
| Bootstrap | apply/destroy local de 16 recursos; versión, cifrado, acceso público y política de clave KMS comprobados | Configuración del plano de control; cumplimiento, federación AWS, migración y bloqueo concurrente sin verificar |
| Aprovisionamiento DEV | apply/destroy de 223 recursos desde entorno limpio; topología y protocolos PostgreSQL/Redis aprobados | Segundo plan: 8 reemplazos y 18 actualizaciones conocidos; 0 inesperados; control aprobado |
| Aprovisionamiento PROD | apply/destroy de 233 recursos desde entorno limpio; topología y protocolos PostgreSQL/Redis aprobados | Segundo plan: 16 reemplazos y 18 actualizaciones conocidos; 0 inesperados; control aprobado |
| PostgreSQL | Ambos contenedores aprobaron transacciones con tablas temporales | No demuestra acceso VPC, TLS ni conmutación por fallo |
| Redis | SET/GET/DEL reales aprobados | Grupos IAM no soportados; no demuestra cumplimiento TLS/IAM |
| Red, endpoints, ALB, CDN, logs | Aprovisionados mediante plano de control local | Filtrado, arranque EC2, enrutamiento ALB, cumplimiento OAC y entrega del agente no certificados |
| Costos y diagrama | Fórmulas recalculadas y examinadas; renders inspeccionados | Precios provisionales |
| Workflows AWS | OIDC y control deshabilitado por defecto implementados | No ejecutados en GitHub/AWS |

El control acepta únicamente firmas conocidas por tipo, rutas modificadas,
rutas de reemplazo y relación de dependencia. Cualquier diferencia inesperada
falla la integración. Los cambios conocidos siguen visibles: no es cero drift
ni evidencia de drift en AWS. No se añadió ignore_changes ni se debilitó la seguridad.

Los logs, estados y planes sin procesar permanecen ignorados. Reproduce con
scripts/local.py; CI publica conteos saneados. Las pruebas destructivas usaron
el puerto dedicado 4567; Floci original en 4566 se preservó.
Los estados locales quedaron vacíos y se retiraron el contenedor y volumen dedicados.

### Investigación específica de drift

DEV y PROD se ejecutaron con el código actual, cada uno contra un contenedor
Floci dedicado nuevo en 4567 y estado local vacío. Ambos controles pasaron:
DEV registró 26 recursos con diferencias conocidas y PROD 34; ambos tuvieron
0 inesperados. Las 19 pruebas Python cubren rechazo de cambios en confianza IAM,
AMI, tipo de instancia, subred y seguridad EC2, dependencia de attachments y
redacción de datos sensibles. El cifrado es la única ruta admitida de reemplazo EC2.
No se encontró defecto de configuración Terraform de categoría A en el drift.

| Entorno | Solo actualización | Reemplazo | Solo eliminación | Solo creación |
| --- | ---: | ---: | ---: | ---: |
| DEV | 18 | 8 | 0 | 0 |
| PROD | 18 | 16 | 0 | 0 |

Los reemplazos se cuentan por separado: los totales operativos de Terraform
incluyen 8 creaciones/8 destrucciones en DEV y 16 creaciones/16 destrucciones en PROD.

Los diagnósticos saneados por recurso se generan en `.local/dev/drift-details.json`
y `.local/prod/drift-details.json`; ambos entornos generaron drift-summary.json y drift-counts.json.
Estos informes ignorados son salidas locales y no se distribuyen en el repositorio.
Reproduce la extracción sin conexión con `python scripts/drift.py dev` o `prod`.
El extractor conserva rutas modificadas, marcadores desconocidos y rutas de
reemplazo, redacta subárboles sensibles y excluye valores de credenciales/user-data/políticas.
Nunca escribe el JSON completo del plan ni el estado en un informe.

| Tipo de recurso (cantidad DEV / PROD) | Atributos exactos de la causa raíz | Clasificación |
| --- | --- | --- |
| aws_instance (4 / 8) | `root_block_device[0].encrypted`: false -> true, **única** replace_path; volume_size también 8 -> 12; vpc_security_group_ids devuelve grupo predeterminado en vez del configurado | C: valores predeterminados/procesamiento ENI del emulador. Los valores calculados desconocidos son consecuencias D; valores opcionales calculados como credit_specification/hibernation son normalización B, no causas de reemplazo |
| aws_lb_target_group_attachment (4 / 8) | `target_id`: ID existente -> desconocido; única ruta de reemplazo; port y target_group_arn sin cambios | D: consecuencia del reemplazo EC2 |
| aws_cloudfront_distribution (1 / 1) | tags.Name y tags_all.{Name,Project,Environment,ManagedBy}: ausentes -> configurados | C: creación usa clave distribution/id; lectura usa ARN completo |
| aws_iam_instance_profile (4 / 4) | tags_all.{Project,Environment,ManagedBy}: ausentes -> configurados | C: handler de creación ignora etiquetas |
| aws_iam_role (4 / 4) | permissions_boundary: vacío -> ARN local configurado | C: creación/XML de lectura omiten el límite |
| aws_db_instance (2 / 2) | storage_type gp2 -> gp3; max_allocated_storage 0 -> 100; enabled_cloudwatch_logs_exports vacío -> postgresql, upgrade | C: respuesta fija gp2 y omite límite de almacenamiento/exportaciones de logs |
| aws_elasticache_replication_group (1 / 1) | security_group_ids vacío -> SG de caché configurado; transit_encryption_mode vacío -> required | C: respuesta de caché omite estos campos |
| aws_network_acl (6 / 6) | tags.Name y tags_all.{Name,Project,Environment,ManagedBy}: ausentes -> configurados | C: CreateNetworkAcl ignora etiquetas; sin drift en reglas ni asociaciones de subred |

Clasificación: A defecto de configuración; B normalización/lectura del proveedor;
C incompatibilidad del emulador; D cambio en cascada. No se estableció un defecto
independiente del proveedor. El reemplazo es el comportamiento esperado: cifrado
es ForceNew y la función de lectura copia Encrypted de la respuesta del volumen.
Consulta la [implementación EC2 del proveedor AWS 6.66.0](https://github.com/hashicorp/terraform-provider-aws/blob/v6.66.0/internal/service/ec2/ec2_instance.go#L862).

La corroboración del código fuente usó Floci 2.1.0, commit
`560b3e4aae61cea3ac7d4d51843bdffd0e3085fd`:

- [Valores predeterminados del volumen raíz EC2](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/ec2/Ec2Service.java#L2659)
- [Procesamiento de solicitudes EC2 y creación ACL](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/ec2/Ec2QueryHandler.java#L3654)
- [Handlers IAM y serialización de respuestas](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/iam/IamQueryHandler.java#L656)
- [Serialización de respuestas RDS](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/rds/RdsQueryHandler.java#L1477)
- [Serialización de respuestas de caché](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/elasticache/ElastiCacheQueryHandler.java#L761)
- [Almacenamiento de etiquetas CloudFront](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/cloudfront/CloudFrontService.java#L147)

No se usó ignore_changes ni se debilitó la seguridad. No se realizaron operaciones
AWS reales. El drift conocido permanece visible; ambos controles de integración pasan.

---

# English

## Validation matrix

Local evidence recorded 2026-09-24: Terraform 1.16.2, AWS provider 6.66.0,
Floci 2.1.0 pinned by digest. No real AWS operations were performed.

| Area | Evidence obtained | Remaining limits |
| --- | --- | --- |
| Terraform | Root/bootstrap validate; nine root mocked tests and one bootstrap test passed | Not AWS deployment evidence |
| Harness and deployment gates | Nineteen Python safety/diagnostic tests passed | GitHub environment protections require configuration |
| Static analysis | TFLint, actionlint and Gitleaks passed locally | Not a complete security audit |
| Bootstrap | Local apply/destroy of 16 resources; versioning, encryption, public access and KMS key policy checked | Control-plane configuration; enforcement, AWS federation, migration and concurrent locking unverified |
| DEV provisioning | Fresh current-code apply/destroy of 223 resources; topology and PostgreSQL/Redis protocol checks passed | Second plan: 8 replacements and 18 updates known; 0 unexpected; gate passed |
| PROD provisioning | Fresh current-code apply/destroy of 233 resources; topology and PostgreSQL/Redis protocol checks passed | Second plan: 16 replacements and 18 updates known; 0 unexpected; gate passed |
| PostgreSQL | Both database containers passed temporary-table transactions | Docker protocol tests do not prove VPC access, TLS or failover |
| Redis | Actual SET/GET/DEL passed | IAM groups unsupported; no TLS/IAM enforcement proof |
| Network, endpoints, ALB, CDN, logs | Provisioned through local control plane | Packet filtering, EC2 boot, ALB routing, OAC enforcement and agent delivery not certified |
| Costs and diagram | Formulas recalculated and error-scanned; renders inspected | Prices provisional |
| AWS workflows | OIDC and default-disabled gate implemented | Not executed on GitHub/AWS |

The gate accepts only known signatures by type, changed paths, replacement
paths and dependency relationship. Any unexpected difference fails integration.
Known changes remain visible: this is neither zero drift nor evidence of AWS
drift. No ignore_changes or security weakening was introduced.

Raw logs, state and plans remain ignored. Reproduce with scripts/local.py;
CI publishes sanitized counts. Destructive tests used dedicated port 4567;
the original Floci on port 4566 was preserved.
Local states are empty; the dedicated container and volume were removed.

### Focused drift investigation

DEV and PROD ran with current code, each against a fresh dedicated Floci
container on port 4567 and empty local state. Both gates passed: DEV reported
26 resources with known differences and PROD 34; both had 0 unexpected.
The 19 Python tests cover rejection of IAM trust, AMI, instance type, subnet
and EC2 security changes, attachment dependencies and sensitive-data redaction.
Encryption is the only accepted EC2 replacement path.
No category A Terraform configuration defect was found in the drift.

| Environment | Update-only | Replace | Delete-only | Create-only |
| --- | ---: | ---: | ---: | ---: |
| DEV | 18 | 8 | 0 | 0 |
| PROD | 18 | 16 | 0 | 0 |

Replacements are counted separately: Terraform's operation totals include
8 creates/8 destroys in DEV and 16 creates/16 destroys in PROD.

Sanitized per-resource diagnostics are in `.local/dev/drift-details.json` and
`.local/prod/drift-details.json`; both environments generated drift-summary.json and drift-counts.json. These ignored reports are local
outputs, not files distributed with the repository.
Reproduce extraction offline with `python scripts/drift.py dev` or `prod`.
The extractor retains changed paths, unknown markers and replacement paths,
redacts sensitive subtrees and excludes credential/user-data/policy values.
It never writes the full plan JSON or state into a report.

| Resource type (DEV / PROD count) | Exact root-cause attributes | Classification |
| --- | --- | --- |
| aws_instance (4 / 8) | `root_block_device[0].encrypted`: false -> true, the **only** replace_path; volume_size also 8 -> 12; vpc_security_group_ids returns default group instead of configured group | C: emulator defaults/ENI input handling. Computed unknown values are D consequences; optional computed defaults such as credit_specification/hibernation are B normalization, not replacement triggers |
| aws_lb_target_group_attachment (4 / 8) | `target_id`: existing instance ID -> unknown; only replacement path; port and target_group_arn unchanged | D: downstream EC2 replacement |
| aws_cloudfront_distribution (1 / 1) | tags.Name and tags_all.{Name,Project,Environment,ManagedBy}: absent -> configured | C: creation uses distribution/id tag-store key; tag lookup uses full ARN |
| aws_iam_instance_profile (4 / 4) | tags_all.{Project,Environment,ManagedBy}: absent -> configured | C: creation handler ignores tags |
| aws_iam_role (4 / 4) | permissions_boundary: empty -> configured local boundary ARN | C: creation handler/read XML omit boundary |
| aws_db_instance (2 / 2) | storage_type gp2 -> gp3; max_allocated_storage 0 -> 100; enabled_cloudwatch_logs_exports empty -> postgresql, upgrade | C: RDS response hardcodes gp2 and omits storage ceiling/log exports |
| aws_elasticache_replication_group (1 / 1) | security_group_ids empty -> configured cache SG; transit_encryption_mode empty -> required | C: cache response omits these fields |
| aws_network_acl (6 / 6) | tags.Name and tags_all.{Name,Project,Environment,ManagedBy}: absent -> configured | C: CreateNetworkAcl ignores tag specifications; no rule or subnet-association drift |

Classification: A configuration defect; B provider normalization/read-back;
C emulator incompatibility; D cascading change. No independent provider defect
was established. Provider replacement behavior is expected: encryption is ForceNew,
and its read function copies the volume's Encrypted response. See the pinned
[AWS provider 6.66.0 EC2 implementation](https://github.com/hashicorp/terraform-provider-aws/blob/v6.66.0/internal/service/ec2/ec2_instance.go#L862).

Source corroboration used Floci tag 2.1.0, commit
`560b3e4aae61cea3ac7d4d51843bdffd0e3085fd`:

- [EC2 root volume defaults](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/ec2/Ec2Service.java#L2659)
- [EC2 request parsing and ACL creation](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/ec2/Ec2QueryHandler.java#L3654)
- [IAM handlers and response serialization](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/iam/IamQueryHandler.java#L656)
- [RDS response serialization](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/rds/RdsQueryHandler.java#L1477)
- [Cache response serialization](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/elasticache/ElastiCacheQueryHandler.java#L761)
- [CloudFront tag storage](https://github.com/floci-io/floci/blob/560b3e4aae61cea3ac7d4d51843bdffd0e3085fd/src/main/java/io/github/hectorvent/floci/services/cloudfront/CloudFrontService.java#L147)

No ignore_changes or security weakening were used. No real AWS operations were performed. Known drift remains visible; both integration gates pass.
