package service

import (
	"context"
	"log"
	"sync"
	"time"

	"github.com/go-redis/redis/v8"
)

type RedisHealthChecker struct {
	client        *redis.Client
	isHealthy     bool
	mutex         sync.RWMutex
	checkInterval time.Duration
}

func NewRedisHealthChecker(client *redis.Client, checkInterval time.Duration) *RedisHealthChecker {
	return &RedisHealthChecker{
		client:        client,
		isHealthy:     true,
		checkInterval: checkInterval,
	}
}

func (r *RedisHealthChecker) IsHealthy() bool {
	r.mutex.RLock()
	defer r.mutex.RUnlock()
	return r.isHealthy
}

func (r *RedisHealthChecker) StartHealthCheck(ctx context.Context) {
	ticker := time.NewTicker(r.checkInterval)
	defer ticker.Stop()

	log.Println("Redis health checker started")

	for {
		select {
		case <-ticker.C:
			r.checkHealth()
		case <-ctx.Done():
			log.Println("Redis health checker stopped")
			return
		}
	}
}

func (r *RedisHealthChecker) checkHealth() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	err := r.client.Ping(ctx).Err()

	r.mutex.Lock()
	wasHealthy := r.isHealthy
	r.isHealthy = (err == nil)

	if !wasHealthy && r.isHealthy {
		log.Println("✅ Redis is back online")
	} else if wasHealthy && !r.isHealthy {
		log.Printf("❌ Redis is down: %v", err)
	}
	r.mutex.Unlock()
}

func (r *RedisHealthChecker) TestConnection(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	return r.client.Ping(ctx).Err()
}
