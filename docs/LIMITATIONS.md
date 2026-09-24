# Español

## Limitaciones y requisitos previos al lanzamiento

No se ha accedido ni desplegado en una cuenta AWS real. Terraform validate y los
planes simulados verifican propiedades de esquema/configuración, no la posibilidad
de desplegar bajo permisos, cuotas o SCP de una organización.

Floci no demuestra aislamiento de paquetes AWS, fiabilidad NAT/peering,
independencia de AZ, confianza de certificados, federación OIDC, cifrado en reposo,
conmutación RDS real ni comportamiento global de CloudFront. El soporte parcial
del emulador nunca debe describirse como evidencia de despliegue AWS.

Las aplicaciones son servicios de prueba de infraestructura. Producción requiere
artefactos reales, autenticación/autorización, usuarios de base de datos restringidos,
secretos de aplicación poblados, clientes Redis IAM probados, dimensionamiento,
responsables de alertas y ejercicios de restauración. La salida HTTPS de las
aplicaciones está restringida por puerto, no por dominio.

IAM de despliegue usa listas explícitas de acciones y restricciones regionales,
pero varias acciones tienen recursos comodín. Revisa los alcances de recursos/etiquetas
frente a las políticas de la organización antes de habilitarlo. No se configura
AdministratorAccess ni credenciales permanentes.

La disponibilidad regional de motores/AMI no se ha verificado contra AWS. Los
motores y tamaños predeterminados requieren revisión previa al despliegue. Los
costos son entradas provisionales, no cotizaciones regionales verificadas. Las
pruebas dedicadas Floci requieren recursos Docker y pueden necesitar puertos
adicionales publicados para clientes directos de bases de datos.

---

# English

## Limitations and launch prerequisites

No real AWS account has been accessed or deployed. Terraform validation and
mocked plans establish schema/configuration properties, not AWS deployability
under an organization's permissions, quotas or SCPs.

Floci cannot establish AWS network packet isolation, NAT/peering reliability,
AZ independence, certificate trust, OIDC federation, encryption at rest, genuine
RDS failover or CloudFront global edge behavior. Partial emulator support must
never be described as AWS deployment evidence.

Application payloads are infrastructure smoke services. Production needs real
artifacts, authentication/authorization, restricted database users and populated
application secrets, tested Redis
IAM clients, capacity sizing, alerting ownership and restore exercises.
Application HTTPS egress is port-restricted but not domain-filtered.

Deployment IAM uses explicit service mutation lists and region constraints, but
several service actions have wildcard resources. Resource/tag scoping should be
reviewed against organization policies before enablement. No AdministratorAccess
or long-lived credentials are configured.

Regional engine/AMI availability has not been verified against AWS. Supplied engine defaults and sizes require pre-deployment review.
Costs are provisional planning inputs, not verified regional quotes. Dedicated
Floci tests require Docker resources and may need additional published protocol
ports for direct database/client tests.
