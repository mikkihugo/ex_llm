# Singularity GitHub App - Scaling Guide

## Overview
The Singularity GitHub App is designed for horizontal scaling across multiple deployment platforms. The architecture supports scaling from single-server deployments to enterprise-grade distributed systems.

## Architecture for Scaling

### Stateless Application Design
- **Elixir/Phoenix**: Stateless web layer, perfect for horizontal scaling
- **External State**: PostgreSQL for data, Redis for caching/sessions
- **Health Checks**: Built-in readiness/liveness probes for orchestration
- **Containerized**: Docker-based deployment for portability

### Scaling Dimensions

#### 1. Horizontal Scaling (Application Layer)
```bash
# Docker Compose scaling
docker-compose up -d --scale app=5

# Kubernetes HPA (auto-scaling based on CPU/memory)
kubectl autoscale deployment singularity-github-app --cpu-percent=70 --min=2 --max=10
```

#### 2. Database Scaling
- **Read Replicas**: PostgreSQL streaming replication
- **Connection Pooling**: PgBouncer for high concurrency
- **Sharding**: Future option for massive scale

#### 3. Caching Layer
- **Redis Cluster**: For distributed caching
- **Redis Sentinel**: High availability setup

## Platform-Specific Scaling

### Docker Compose (Development/Production)
```bash
# Scale application instances
docker-compose up -d --scale app=3

# Scale with load balancer
docker-compose up -d --scale app=5 nginx=2

# Resource limits
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

### Kubernetes (Production Scaling)
```bash
# Manual scaling
kubectl scale deployment singularity-github-app --replicas=5

# Auto-scaling based on metrics
kubectl apply -f k8s-hpa.yml

# Scale based on custom metrics (analysis queue length)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: analysis-queue-hpa
spec:
  metrics:
  - type: External
    external:
      metric:
        name: analysis_queue_length
      target:
        type: AverageValue
        averageValue: "10"
```

### AWS ECS/Fargate (Serverless Scaling)
```yaml
# ECS Service with auto-scaling
Resources:
  SingularityService:
    Type: AWS::ECS::Service
    Properties:
      DesiredCount: 2
      DeploymentConfiguration:
        MaximumPercent: 200
        MinimumHealthyPercent: 50

  SingularityScalingPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Properties:
      PolicyType: TargetTrackingScaling
      TargetTrackingScalingPolicyConfiguration:
        TargetValue: 70.0
        PredefinedMetricSpecification:
          PredefinedMetricType: ECSServiceAverageCPUUtilization
```

### Google Cloud Run (Serverless)
```yaml
# Cloud Run service (scales to zero)
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: singularity-github-app
spec:
  template:
    spec:
      containers:
      - image: gcr.io/project/singularity-github-app
        ports:
        - containerPort: 4000
        env:
        - name: PORT
          value: "4000"
        resources:
          limits:
            cpu: 1000m
            memory: 512Mi
```

## Performance Optimization

### Application-Level Scaling
- **Connection Pooling**: Ecto connection pools per instance
- **Async Processing**: ex_pgflow for background analysis jobs
- **Caching Strategy**: Redis for session/analysis result caching
- **Rate Limiting**: Built-in protection against abuse

### Database Optimization
```sql
-- Connection pooling with PgBouncer
-- Read/write splitting for high read loads
-- Partitioning for large analysis result tables
```

### Monitoring & Scaling Triggers

#### Key Metrics to Monitor
- **Request Latency**: P95 response time < 500ms
- **Analysis Queue Length**: Keep under 100 pending analyses
- **Database Connections**: Monitor pool utilization
- **Memory/CPU Usage**: Scale before hitting limits

#### Scaling Policies
```yaml
# Scale up when queue gets long
- metric: analysis_queue_length
  threshold: 50
  scale_up: +2 instances

# Scale down when idle
- metric: cpu_utilization
  threshold: 20
  scale_down: -1 instance
```

## Cost Optimization

### Right-Sizing Resources
- **Development**: 256MB RAM, 0.25 CPU
- **Production**: 512MB RAM, 0.5 CPU per instance
- **High Load**: 1GB RAM, 1 CPU per instance

### Scaling Strategies
- **Predictive Scaling**: Based on historical GitHub webhook patterns
- **Scheduled Scaling**: Scale up during business hours
- **Event-Driven**: Scale based on webhook volume

## Deployment Examples

### Single Server (Development)
```bash
docker-compose up -d
# 1 app instance, 1 DB, 1 Redis
```

### Small Production
```bash
docker-compose up -d --scale app=2
# 2 app instances behind nginx
```

### Enterprise Scale
```bash
# Kubernetes with 5-10 pods
kubectl apply -f k8s-deployment.yml

# AWS ECS with auto-scaling
aws ecs update-service --cluster cluster --service service --desired-count 5

# Multi-region deployment
# Deploy to us-east-1, eu-west-1, ap-southeast-1
```

## Scaling Limits & Considerations

### Theoretical Limits
- **Docker Compose**: ~10-20 instances per host
- **Kubernetes**: 1000+ pods per cluster
- **AWS ECS**: Unlimited with proper configuration
- **Database**: PostgreSQL can handle 10k+ concurrent connections with pooling

### Practical Considerations
- **Database Connection Limits**: Ensure proper pooling
- **Network Latency**: Keep app instances close to database
- **State Management**: Redis clustering for distributed sessions
- **Cost Monitoring**: Scale down during low-usage periods

## Monitoring Scaling

### Key Metrics
```bash
# Application metrics
docker stats
kubectl top pods

# Queue monitoring
redis-cli LLEN analysis_queue

# Database monitoring
docker-compose exec db pg_stat_activity
```

### Alerting
- Scale up alerts: High queue length, high latency
- Scale down alerts: Low utilization for extended periods
- Database alerts: Connection pool exhaustion, slow queries

This architecture scales from a single developer machine to enterprise-grade deployments handling millions of analyses per month.