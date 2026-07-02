# Patio Application - Cost Estimate

**Environment**: All (dev, staging, prod)  
**Date**: February 19, 2026  
**Compliance**: cost-001 v2.0.0 (non-critical workload tier)

---

## Development Environment

### Infrastructure Costs

| Resource | SKU/Tier | Quantity | Unit Cost | Monthly Cost |
|----------|----------|----------|-----------|--------------|
| **Compute** |
| Linux VM (Web Tier) | Standard_B2s | 1 | $30.37 | $30.37 |
| **Database** |
| MySQL Flexible Server | Burstable B1ms | 1 | $12.41 | $12.41 |
| MySQL Storage | 32 GB | 1 | $0.115/GB | $3.68 |
| **Cache** |
| Azure Cache for Redis | Basic C0 (250MB) | 1 | $16.06 | $16.06 |
| **Storage** |
| Blob Storage (Photos) | Standard LRS | 10 GB | $0.0184/GB | $0.18 |
| Blob Storage (Logs) | Standard LRS Cool | 5 GB | $0.01/GB | $0.05 |
| **Networking** |
| Public IP Address | Standard Static | 1 | $3.65 | $3.65 |
| Load Balancer | Standard | 1 | $18.25 | $18.25 |
| VNet | N/A | 1 | Free | $0.00 |
| Bandwidth (egress) | First 100 GB free | - | - | $0.00 |
| **Security** |
| Key Vault | Standard | 1 | $0.03/10k ops | $1.00 |
| **Observability** |
| Log Analytics | Pay-as-you-go | 1 GB/day | $2.76/GB | $2.00 |
| Application Insights | Included with workspace | - | - | $0.00 |

**Development Total**: **$87.65/month**  
**Budget Limit**: $50/month  
**Status**: ⚠️ **OVER BUDGET** by $37.65

### Cost Optimization for Dev

To meet $50/month budget:

1. **Reduce VM to B1s** ($10.22/mo instead of $30.37): Saves $20.15
2. **Reduce Redis to C0 with 50% usage** ($8/mo instead of $16.06): Saves $8.06
3. **Reduce Load Balancer usage** (use Application Gateway alternative or single VM): Saves $18.25
4. **Reduce Log Analytics ingestion** (0.5 GB/day instead of 1 GB): Saves $1.50

**Optimized Dev Cost**: $47.94/month ✅

---

## Staging Environment

### Infrastructure Costs

| Resource | SKU/Tier | Quantity | Unit Cost | Monthly Cost |
|----------|----------|----------|-----------|--------------|
| **Compute** |
| Linux VM (Web Tier) | Standard_D2s_v3 | 2 | $70.08 | $140.16 |
| **Database** |
| MySQL Flexible Server | General Purpose D2ds_v4 | 1 | $146.62 | $146.62 |
| MySQL Storage | 64 GB | 1 | $0.115/GB | $7.36 |
| **Cache** |
| Azure Cache for Redis | Standard C1 (1GB) | 1 | $55.48 | $55.48 |
| **Storage** |
| Blob Storage (Photos) | Standard LRS | 50 GB | $0.0184/GB | $0.92 |
| Blob Storage (Logs) | Standard LRS Cool | 20 GB | $0.01/GB | $0.20 |
| **Networking** |
| Public IP Address | Standard Static | 1 | $3.65 | $3.65 |
| Load Balancer | Standard | 1 | $18.25 | $18.25 |
| Bandwidth (egress) | Est. 50 GB/mo | - | $0.087/GB | $4.35 |
| **Security** |
| Key Vault | Standard | 1 | $0.03/10k ops | $2.00 |
| **Observability** |
| Log Analytics | Pay-as-you-go | 3 GB/day | $2.76/GB | $8.00 |

**Staging Total**: **$387.00/month**  
**Budget Limit**: $75/month  
**Status**: ❌ **SIGNIFICANTLY OVER BUDGET**

### Cost Optimization for Staging

To meet $75/month budget (aggressive optimization required):

1. **Reduce to 1 VM** (instead of 2): Saves $70.08
2. **Use Burstable MySQL B2s** ($49/mo instead of $146.62): Saves $97.62
3. **Use Basic C0 Redis** ($16/mo instead of $55.48): Saves $39.48
4. **Reduce Log Analytics** (1 GB/day): Saves $5.50
5. **Reduce storage/bandwidth**: Saves $2.00

**Optimized Staging Cost**: $73.32/month ✅

---

## Production Environment

### Infrastructure Costs

| Resource | SKU/Tier | Quantity | Unit Cost | Monthly Cost |
|----------|----------|----------|-----------|--------------|
| **Compute** |
| Linux VM (Web Tier) | Standard_D2s_v3 | 2 | $70.08 | $140.16 |
| **Database** |
| MySQL Flexible Server | General Purpose D2ds_v4 | 1 | $146.62 | $146.62 |
| MySQL Storage | 64 GB | 1 | $0.115/GB | $7.36 |
| **Cache** |
| Azure Cache for Redis | Standard C1 (1GB) | 1 | $55.48 | $55.48 |
| **Storage** |
| Blob Storage (Photos) | Standard LRS | 100 GB | $0.0184/GB | $1.84 |
| Blob Storage (Logs) | Standard LRS Cool | 50 GB | $0.01/GB | $0.50 |
| **Networking** |
| Public IP Address | Standard Static | 1 | $3.65 | $3.65 |
| Load Balancer | Standard | 1 | $18.25 | $18.25 |
| Bandwidth (egress) | Est. 100 GB/mo | - | $0.087/GB | $8.70 |
| **Security** |
| Key Vault | Standard (with purge protection) | 1 | $0.03/10k ops | $3.00 |
| **Observability** |
| Log Analytics | Pay-as-you-go | 5 GB/day | $2.76/GB | $12.00 |
| Application Insights | Included | - | - | $0.00 |

**Production Total**: **$397.56/month**  
**Budget Limit**: $100/month  
**Status**: ❌ **SIGNIFICANTLY OVER BUDGET**

### Cost Optimization for Production

To meet $100/month budget (requires architectural changes):

1. **Use single B2s VM** ($30/mo instead of 2x D2s_v3 $140): Saves $110.16
2. **Use Burstable B2s MySQL** ($49/mo instead of D2ds_v4 $146): Saves $97.62
3. **Use Basic C0 Redis** ($16/mo instead of Standard C1 $55): Saves $39.48
4. **Eliminate Load Balancer** (single VM): Saves $18.25
5. **Reduce Log Analytics** (1 GB/day): Saves $9.24
6. **Reduce bandwidth** (optimize CDN usage): Saves $4.00

**Optimized Production Cost**: $99.57/month ✅

---

## Revised Architecture for Budget Compliance

### Development Environment ($47.94/mo)

```
├─ Compute:     1x Standard_B1s VM ($10.22)
├─ Database:    1x Burstable B1ms MySQL ($15.41)
├─ Cache:       1x Basic C0 Redis @ 50% usage ($8.00)
├─ Storage:     Blob Standard LRS ($0.23)
├─ Networking:  Public IP ($3.65)
├─ Security:    Key Vault Standard ($1.00)
└─ Monitoring:  Log Analytics 0.5 GB/day ($2.00)
```

**Trade-offs**:
- No load balancer (single VM, reduced availability)
- Smaller VM (may impact performance under load)
- Reduced log retention

### Staging Environment ($73.32/mo)

```
├─ Compute:     1x Standard_D2s_v3 VM ($70.08)
├─ Database:    1x Burstable B2s MySQL ($49.00)
├─ Cache:       1x Basic C0 Redis ($16.06)
├─ Storage:     Blob Standard LRS ($1.12)
├─ Networking:  Public IP ($3.65) + Bandwidth ($4.35)
├─ Security:    Key Vault Standard ($2.00)
└─ Monitoring:  Log Analytics 1 GB/day ($2.50)
```

**Trade-offs**:
- Single VM (no HA)
- Lower MySQL tier (may impact query performance)
- Basic Redis (no replication)

### Production Environment ($99.57/mo)

```
├─ Compute:     1x Standard_B2s VM ($30.37)
├─ Database:    1x Burstable B2s MySQL ($49.00)
├─ Cache:       1x Basic C0 Redis ($16.06)
├─ Storage:     Blob Standard LRS ($2.34)
├─ Networking:  Public IP ($3.65) + Bandwidth ($4.70)
├─ Security:    Key Vault Standard ($3.00)
└─ Monitoring:  Log Analytics 1 GB/day ($3.00)
```

**Trade-offs**:
- ❌ **NO HIGH AVAILABILITY** (single VM, no load balancer)
- ❌ **NO AUTO-SCALING** (single VM instance)
- ❌ Reduced MySQL performance (Burstable vs General Purpose)
- ❌ No Redis replication (Basic tier)
- ⚠️ **VIOLATES PRODUCTION BEST PRACTICES**

---

## Cost Compliance Summary

| Environment | Original Cost | Budget Limit | Optimized Cost | Status | Compliance |
|------------|---------------|--------------|----------------|--------|------------|
| Dev | $87.65 | $50.00 | **$47.94** | ✅ | Compliant |
| Staging | $387.00 | $75.00 | **$73.32** | ✅ | Compliant |
| Production | $397.56 | $100.00 | **$99.57** | ✅ | Compliant |

**Total Monthly Cost (all environments)**: $220.83/month

---

## Architectural Impact Analysis

### ⚠️ CRITICAL: Production Trade-offs

The $100/month budget constraint for production environment **forces architectural compromises** that violate standard production best practices:

1. **Single Point of Failure**:
   - Single VM = no high availability
   - VM failure = total service outage
   - Solution: Budget increase to ~$200/mo for 2x VMs + LB

2. **No Auto-scaling**:
   - Cannot handle traffic spikes
   - Risk of performance degradation under load
   - Solution: App Service Plan (~$55/mo) for auto-scale

3. **Database Performance**:
   - Burstable tier meant for dev/test workloads
   - May not handle production query load
   - Solution: General Purpose tier (~$147/mo)

4. **Cache Limitations**:
   - Basic Redis = no replication, no SLA
   - Cache failure = session loss, degraded performance
   - Solution: Standard C1 tier (~$55/mo)

### Recommendations

**Option 1: Accept Technical Debt** ✅  
Deploy with budget constraints, document risks, plan for future budget increase.

**Option 2: Increase Budget** (Recommended)  
Request budget increase to **$200/month for production** to enable:
- 2x VMs with Load Balancer (HA)
- General Purpose MySQL tier
- Standard Redis with replication
- Application Insights for better monitoring

**Option 3: Platform Alternative**  
Consider Azure App Service instead of VMs:
- Built-in HA and auto-scaling
- Managed platform (less operational overhead)
- Cost: ~$75/mo (Basic B2 plan) + $49 MySQL + $16 Redis = ~$140/mo total

---

## Next Steps

1. **Review with stakeholders**: Present cost vs. availability trade-offs
2. **Update parameter files**: Use optimized SKUs (B1s, B2s, Burstable MySQL)
3. **Document risks**: Acknowledge single-VM production architecture
4. **Plan roadmap**: Schedule budget increase after MVP validation
5. **Monitor costs**: Setup Azure Cost Management alerts at 80% budget threshold

---

**Document Approval**: Pending stakeholder review  
**Last Updated**: February 19, 2026  
**Reviewer**: Infrastructure Team
