package service

import (
	"context"
	"fmt"

	"sub-balance-demo/internal/config"

	"github.com/go-redis/redis/v8"
	"github.com/shopspring/decimal"
)

type RedisCounter interface {
	GetPending(ctx context.Context, accountID string) (decimal.Decimal, error)
	AddPending(ctx context.Context, accountID string, amount decimal.Decimal, maxBalance decimal.Decimal) (bool, decimal.Decimal, error)
	RemovePending(ctx context.Context, accountID string, amount decimal.Decimal) error
	ClearPending(ctx context.Context, accountID string) error
}

type redisCounter struct {
	client    *redis.Client
	keyPrefix string
	keyExpiry int
}

func NewRedisCounter(client *redis.Client, config *config.Config) RedisCounter {
	return &redisCounter{
		client:    client,
		keyPrefix: config.RedisKeyPrefix,
		keyExpiry: config.RedisKeyExpiry,
	}
}

func (r *redisCounter) GetPending(ctx context.Context, accountID string) (decimal.Decimal, error) {
	key := fmt.Sprintf("%s:pending:%s", r.keyPrefix, accountID)

	result := r.client.Get(ctx, key)
	if result.Err() != nil {
		if result.Err() == redis.Nil {
			return decimal.Zero, nil
		}
		return decimal.Zero, result.Err()
	}

	value, err := decimal.NewFromString(result.Val())
	if err != nil {
		return decimal.Zero, err
	}

	return value, nil
}

func (r *redisCounter) AddPending(ctx context.Context, accountID string, amount decimal.Decimal, maxBalance decimal.Decimal) (bool, decimal.Decimal, error) {
	key := fmt.Sprintf("%s:pending:%s", r.keyPrefix, accountID)

	// Atomic script untuk validation + update
	script := `
		local key = KEYS[1]
		local amount = tonumber(ARGV[1])
		local maxBalance = tonumber(ARGV[2])
		
		-- Get current pending amount
		local current = redis.call('GET', key)
		if current == false then
			current = 0
		else
			current = tonumber(current)
		end
		
		-- Calculate new total
		local newTotal = current + amount
		
		-- Validation: tidak boleh overspend
		if newTotal > maxBalance then
			return {0, current, "overspend protection"}
		end
		
		-- Validation: tidak boleh minus
		if newTotal < 0 then
			return {0, current, "negative balance"}
		end
		
		-- Atomic update
		redis.call('SET', key, newTotal)
		redis.call('EXPIRE', key, ARGV[3])
		
		return {1, newTotal, "success"}
	`

	result := r.client.Eval(ctx, script, []string{key}, amount.InexactFloat64(), maxBalance.InexactFloat64(), r.keyExpiry)
	if result.Err() != nil {
		return false, decimal.Zero, result.Err()
	}

	values := result.Val().([]interface{})
	success := values[0].(int64)

	// Handle both int64 and float64 return types from Redis
	var newTotal decimal.Decimal
	switch v := values[1].(type) {
	case float64:
		newTotal = decimal.NewFromFloat(v)
	case int64:
		newTotal = decimal.NewFromInt(v)
	case string:
		var err error
		newTotal, err = decimal.NewFromString(v)
		if err != nil {
			return false, decimal.Zero, fmt.Errorf("failed to parse total from Redis: %v", err)
		}
	default:
		return false, decimal.Zero, fmt.Errorf("unexpected type for total from Redis: %T", v)
	}

	return success == 1, newTotal, nil
}

func (r *redisCounter) RemovePending(ctx context.Context, accountID string, amount decimal.Decimal) error {
	key := fmt.Sprintf("%s:pending:%s", r.keyPrefix, accountID)

	// Atomic decrement
	script := `
		local key = KEYS[1]
		local amount = tonumber(ARGV[1])
		
		local current = redis.call('GET', key)
		if current == false then
			current = 0
		else
			current = tonumber(current)
		end
		
		local newTotal = current - amount
		if newTotal < 0 then
			newTotal = 0
		end
		
		redis.call('SET', key, newTotal)
		redis.call('EXPIRE', key, ARGV[2])
		
		return newTotal
	`

	_, err := r.client.Eval(ctx, script, []string{key}, amount.InexactFloat64(), r.keyExpiry).Result()
	return err
}

func (r *redisCounter) ClearPending(ctx context.Context, accountID string) error {
	key := fmt.Sprintf("%s:pending:%s", r.keyPrefix, accountID)
	return r.client.Del(ctx, key).Err()
}
