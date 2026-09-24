# Español

## Modelo de costos mensuales

Abre [costs.xlsx](costs.xlsx) para DEV, PROD y la comparación de cuatro EC2/un NAT.
Las cantidades y tarifas son editables; los totales por fila y escenario son fórmulas.
El modelo usa 730 horas/mes, USD y planificación bajo demanda, sin impuestos,
descuentos, capacidad reservada, créditos ni supuestos de capa gratuita. Los precios
son tarifas provisionales de planificación, no cotizaciones verificadas de Canada
Central. Cada tarifa tiene enlaces de fuentes; la fecha de revisión es 2026-09-23.
Actualiza todas las tarifas antes de aprobar un presupuesto.

Incluye ambas bases de datos/réplicas de espera/almacenamiento/copias, Redis,
EC2/EBS, ALB/LCU, procesamiento NAT, asignación mínima de IPv4 públicas, transferencia
entre AZ, almacenamiento/solicitudes S3 (estado/logs incluidos), CloudFront,
endpoints de Secrets Manager, CloudWatch, Secrets Manager, KMS, DNS y salida a Internet.

Supuestos de tráfico: DEV 100 GB CDN/100 GB NAT/10 GB logs; PROD 1 TB CDN,
300 GB NAT y 50 GB logs. ALB usa una LCU promedio. Las filas de transferencia
representan GB facturables en ambas direcciones cobradas cuando corresponda.
El almacenamiento del backend está incluido en S3. El incremento de tamaño de
bases de datos/caché en PROD es una provisión visible por separado; reemplázala
por cotizaciones reales específicas de cada nodo.

Actualiza las tarifas con los selectores regionales oficiales o
[AWS Pricing Calculator](https://calculator.aws/). Las fuentes incluyen
[ELB](https://aws.amazon.com/elasticloadbalancing/pricing/),
[VPC](https://aws.amazon.com/vpc/pricing/) y
[Secrets Manager](https://aws.amazon.com/secrets-manager/pricing/).
Los costos son supuestos de carga, nunca evidencia de despliegue ni facturación.

El desafío enumera cuatro EC2 como referencia de costos. DEV implementa cuatro
(una por carga); PROD implementa ocho intencionalmente (dos por carga entre dos AZ).
No se implementa Auto Scaling. Esta decisión de disponibilidad eleva el estimado PROD.

---

# English

## Monthly cost model

Open [costs.xlsx](costs.xlsx) for DEV, PROD and the four-EC2/one-NAT comparison.
Quantities and rates are editable; line totals and scenario totals are formulas.
The model uses 730 hours/month, USD, on-demand planning, no taxes, discounts,
reserved capacity, credits or free-tier assumptions. Prices are provisional
planning rates, not verified Canada Central quotes. Source links appear beside
each rate; review date is 2026-09-23. Refresh all rates before budget approval.

Coverage includes both databases/standbys/storage/backups, Redis, EC2/EBS,
ALB/LCU, NAT processing, minimum public IPv4 allocation, cross-AZ transfer,
S3 storage/requests including state/logs, CloudFront, Secrets endpoints,
CloudWatch, Secrets Manager, KMS, DNS and Internet egress.

Traffic assumptions: DEV 100 GB CDN/100 GB NAT/10 GB logs; PROD 1 TB CDN,
300 GB NAT and 50 GB logs. ALB uses one average LCU. Transfer rows represent
billable GB across both charged directions where applicable. Backend storage
is included in S3. PROD database/cache size uplift is a separately visible
provisional allowance; replace it with actual node-specific quotes.

Rates must be refreshed using the official regional selectors or
[AWS Pricing Calculator](https://calculator.aws/). Sources include
[ELB](https://aws.amazon.com/elasticloadbalancing/pricing/),
[VPC](https://aws.amazon.com/vpc/pricing/), and
[Secrets Manager](https://aws.amazon.com/secrets-manager/pricing/).
Costs are workload assumptions, never deployment or billing evidence.

The challenge lists four EC2 as a cost reference. DEV implements four (one per
workload); PROD intentionally implements eight (two per workload across two AZs).
Auto Scaling is not implemented. This availability choice increases the PROD estimate.
