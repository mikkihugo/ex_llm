# Singularity GitHub App - Quick Scaling Commands

## Docker Compose Scaling

### Scale Application Instances
```bash
# Scale to 3 app instances
docker-compose -f docker-compose.prod.yml up -d --scale app=3

# Scale to 5 instances with load balancing
docker-compose -f docker-compose.prod.yml up -d --scale app=5

# Check running instances
docker-compose -f docker-compose.prod.yml ps

# View logs from all instances
docker-compose -f docker-compose.prod.yml logs -f app
```

### Resource Management
```bash
# Check resource usage
docker stats

# Limit resources per container
echo 'services:
  app:
    deploy:
      resources:
        limits:
          cpus: "0.50"
          memory: 512M' >> docker-compose.prod.yml
```

## Kubernetes Scaling

### Manual Scaling
```bash
# Scale deployment to 5 replicas
kubectl scale deployment singularity-github-app --replicas=5

# Check current replicas
kubectl get deployment singularity-github-app

# View pod status
kubectl get pods -l app=singularity-github-app
```

### Auto-Scaling (HPA)
```bash
# Enable horizontal pod autoscaling
kubectl autoscale deployment singularity-github-app --cpu-percent=70 --min=2 --max=10

# Check HPA status
kubectl get hpa

# View scaling events
kubectl describe hpa singularity-github-app
```

## AWS ECS Scaling

### Service Scaling
```bash
# Update service to 5 tasks
aws ecs update-service --cluster singularity-cluster --service singularity-service --desired-count 5

# Check service status
aws ecs describe-services --cluster singularity-cluster --services singularity-service
```

### Auto Scaling
```bash
# Create auto scaling policy
aws application-autoscaling put-scaling-policy \
  --policy-name cpu-scaling \
  --service-namespace ecs \
  --resource-id service/singularity-cluster/singularity-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration "TargetValue=70,PredefinedMetricSpecification={PredefinedMetricType=ECSServiceAverageCPUUtilization}"
```

## Google Cloud Run Scaling

### Manual Scaling
```bash
# Set maximum instances
gcloud run services update singularity-github-app \
  --max-instances 10 \
  --region us-central1

# Check service status
gcloud run services describe singularity-github-app --region us-central1
```

## Monitoring Scaling

### Application Metrics
```bash
# Check health of all instances
curl http://localhost/health

# Monitor analysis queue (Redis)
docker-compose -f docker-compose.prod.yml exec redis redis-cli LLEN analysis_queue

# Database connections
docker-compose -f docker-compose.prod.yml exec db psql -U singularity -d singularity_github_app -c "SELECT count(*) FROM pg_stat_activity;"
```

### Performance Testing
```bash
# Load test with 100 concurrent users
ab -n 1000 -c 100 http://localhost/health

# GitHub webhook simulation
curl -X POST http://localhost/api/webhooks/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d '{"repository":{"id":123},"sender":{"id":456}}'
```

## Scaling Decision Tree

```
High Load Detected?
├── Yes → Check current metrics
│   ├── CPU > 70% → Scale up app instances
│   ├── Memory > 80% → Scale up app instances
│   ├── Queue length > 50 → Scale up app instances
│   └── DB connections > 80% → Scale database
└── No → Check for optimization opportunities
    ├── Low utilization → Consider scale down
    └── Normal load → Monitor and maintain
```

## Emergency Scaling

### Immediate Scale Up
```bash
# Docker emergency scale
docker-compose -f docker-compose.prod.yml up -d --scale app=10

# Kubernetes emergency scale
kubectl scale deployment singularity-github-app --replicas=20

# AWS emergency scale
aws ecs update-service --cluster singularity-cluster --service singularity-service --desired-count 20
```

### Scale Down After Incident
```bash
# Gradual scale down
kubectl scale deployment singularity-github-app --replicas=3
docker-compose -f docker-compose.prod.yml up -d --scale app=3
```