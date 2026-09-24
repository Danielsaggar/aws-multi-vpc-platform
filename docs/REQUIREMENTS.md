# Español

## Trazabilidad de requisitos

| Requisito del desafío | Implementación | Validación |
| --- | --- | --- |
| ca-central-1 | validación de proveedor/entrada | prueba negativa de región incorrecta |
| Dos VPC y peering | módulo network | consultas locales, pruebas CIDR |
| Dos AZ, subredes públicas/privadas | módulo network | conteos y comprobaciones AZ |
| IGW, NAT, EIP | módulo network | aprovisionamiento/lectura local |
| Cuatro aplicaciones privadas | módulo compute | conteos de instancias DEV/PROD |
| ALB y ACM | módulo ingress | configuración de listeners/targets |
| RDS transaccional e histórico | módulo data | comprobaciones de privacidad/cifrado |
| Redis | módulo data | propiedades de replicación; limitación IAM local documentada |
| S3 privado y CloudFront OAC | módulos storage/CDN | políticas/bloqueo público |
| Endpoints S3 y Secrets Manager | módulo endpoints | configuraciones de rutas/ENI |
| SG y NACL | módulo security | reglas y niveles de subred aislados |
| Logs centralizados | observability + user data | configuración de grupos/CloudWatch Agent |
| Logs de acceso ALB | módulos storage + ingress | permisos/atributos del bucket |
| Convención de nombres | locals/nombres de módulos | nombres cortos, etiquetas Name |
| Archivos raíz modulares requeridos | composición raíz | terraform validate |
| Hoja de costos | costs.xlsx | fórmulas y supuestos documentados |
| Fuente del diagrama | diagrams/architecture.mmd | SVG renderizado |
| OIDC, bootstrap de estado | raíz bootstrap | pruebas simuladas de políticas/versionado |
| Separación DEV/PROD | cuentas, tfvars, control de despliegue | pruebas negativas de rama/cuenta |
| Despliegue AWS deshabilitado | workflow deploy-aws | pruebas del control |
| Aprovisionamiento local real | harness/workflow de integración | apply, comprobaciones, destroy reales |

La presencia de un recurso no equivale a una prueba de comportamiento aprobada.
Consulta VALIDATION_MATRIX.md para evidencia y LIMITATIONS.md para validaciones
pendientes. No se ha desplegado en AWS real.

---

# English

## Requirement traceability

| Challenge requirement | Implementation | Validation |
| --- | --- | --- |
| ca-central-1 | provider/input validation | wrong-region negative test |
| Two VPCs and peering | network module | local describe, CIDR tests |
| Two AZs, public/private subnets | network module | counts and AZ assertions |
| IGW, NAT, EIP | network module | local provision/read |
| Four private applications | compute module | DEV/PROD instance counts |
| ALB and ACM | ingress module | listener/target configuration |
| Transactional and historical RDS | data module | private/encrypted assertions |
| Redis | data module | replication properties; IAM local gap documented |
| Private S3 and CloudFront OAC | storage/CDN modules | policy/public-block assertions |
| S3 and Secrets Manager endpoints | endpoints module | route/ENI configurations |
| SGs and NACLs | security module | rules and isolated subnet tiers |
| Centralized logs | observability + user data | groups/agent configuration |
| ALB access logs | storage + ingress modules | bucket permissions/attributes |
| Naming convention | locals/module names | short names, Name tags |
| Modular named root files | root composition | terraform validate |
| Cost spreadsheet | costs.xlsx | formulas and documented assumptions |
| Diagram source | diagrams/architecture.mmd | rendered SVG |
| OIDC, state bootstrap | bootstrap root | mocked policy/versioning tests |
| DEV/PROD separation | accounts, tfvars, deployment gate | branch/account negative tests |
| Disabled AWS delivery | deploy-aws workflow | gate tests |
| Real local provisioning | local harness/integration workflow | actual apply, assertions, destroy |

Presence is not a passing behavior test. See VALIDATION_MATRIX.md for evidence
and LIMITATIONS.md for open validation work. Real AWS is undeployed.
