# Español

## Decisiones de diseño y compromisos

1. Las cuentas separadas aíslan DEV y PROD. El bootstrap y la configuración de
   entornos GitHub deben repetirse; crear cuentas está fuera del alcance.
2. Ocho instancias de aplicación en PROD proporcionan una réplica por aplicación/AZ.
   El ejemplo de costos del desafío enumera cuatro, insuficientes para conmutación
   independiente por fallo de las cuatro aplicaciones.
3. Dos NAT gateways en PROD eliminan la dependencia de salida entre AZ. DEV ahorra
   el costo fijo de un NAT y acepta un punto de fallo de salida en una sola AZ.
4. PostgreSQL atiende ambas cargas de datos; no se añade replicación histórica/ETL.
5. El TLS predeterminado de CloudFront evita ACM en us-east-1. CloudFront/IAM son
   servicios globales y no contradicen el destino regional de las cargas.
6. Los endpoints Secrets Manager usan ENI/DNS privados, no asociaciones con tablas
   de rutas. Los endpoints gateway S3 sí usan tablas. Esto aclara la redacción del desafío.
7. Los logs de acceso de ALB usan SSE-S3 porque ALB lo requiere. El estado usa KMS.
8. Redis IAM evita contraseñas en el estado Terraform. Floci no admite grupos de
   usuarios; el adaptador local los omite sin debilitar los recursos AWS.
9. Las aplicaciones de prueba solo sirven para validación. Los roles EC2 pueden
   leer únicamente su secreto de aplicación, nunca credenciales maestras RDS.
   Los secretos no tienen valores en Terraform. La administración autorizada de
   bases de datos debe crear usuarios restringidos y cargar sus secretos antes
   de iniciar aplicaciones reales.
10. Los planes guardados de despliegue se restringen a un repositorio privado.
    La referencia puede ser pública; usa un fork privado de despliegue o entrega un zip.
11. Las mutaciones regionales usan listas explícitas de acciones y una condición
    de región, pero algunos alcances de recursos siguen siendo amplios. Revísalos
    frente a las políticas IAM de la organización antes de habilitar despliegues;
    no conceden acceso administrativo total.
12. Se usan réplicas EC2 fijas; Auto Scaling y recuperación avanzada ante desastres
    están fuera del alcance del desafío y no se implementan.

---

# English

## Design decisions and trade-offs

1. Separate accounts isolate DEV and PROD. Bootstrap and GitHub environment
   configuration must be repeated; account creation is out of scope.
2. Eight PROD application instances provide one replica per app/AZ. The challenge
   cost example lists four, which cannot independently fail over all four apps.
3. Two PROD NAT gateways remove cross-AZ egress dependency. DEV saves one NAT's
   fixed cost and accepts a single-AZ egress failure mode.
4. PostgreSQL serves both data workloads; no historical replication/ETL is added.
5. Default CloudFront TLS avoids ACM in us-east-1. CloudFront/IAM are inherently
   global services, not violations of the regional workload target.
6. Secrets Manager endpoints use private ENIs/DNS, not route-table associations.
   S3 gateway endpoints use route tables. This corrects imprecise challenge wording.
7. SSE-S3 is used for ALB access logs because ALB requires it. State uses KMS.
8. Redis IAM avoids passwords in Terraform state. Floci user groups are unsupported;
   the local adapter skips them without weakening AWS resources.
9. Smoke apps are validation payloads only. EC2 roles can read only their own
   application secret, never RDS master credentials. Secret containers have no
   values in Terraform. Authorized database administration must create restricted
   database users and populate their secrets before real application launch.
10. Saved deployment plans are restricted to a private deployment repository.
    The reference may be public; use a private deployment fork or deliver a zip.
11. Regional deployment mutations currently use explicit action lists with a
    region condition, but some resource scopes remain broad. Review them against
    organizational IAM policy before enabling deployment; they are not admin access.

12. Fixed EC2 replicas are used; Auto Scaling and advanced disaster recovery are
    outside challenge scope and are not implemented.
