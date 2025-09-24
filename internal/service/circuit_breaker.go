package service

import (
	"errors"
	"sync"
	"time"
)

type CircuitBreakerState string

const (
	StateClosed   CircuitBreakerState = "CLOSED"
	StateOpen     CircuitBreakerState = "OPEN"
	StateHalfOpen CircuitBreakerState = "HALF_OPEN"
)

type CircuitBreaker struct {
	failureCount     int
	failureThreshold int
	timeout          time.Duration
	lastFailureTime  time.Time
	state            CircuitBreakerState
	mutex            sync.RWMutex
}

func NewCircuitBreaker(failureThreshold int, timeout time.Duration) *CircuitBreaker {
	return &CircuitBreaker{
		failureThreshold: failureThreshold,
		timeout:          timeout,
		state:            StateClosed,
	}
}

func (cb *CircuitBreaker) Call(fn func() error) error {
	cb.mutex.Lock()
	defer cb.mutex.Unlock()

	// Check if circuit is open
	if cb.state == StateOpen {
		if time.Since(cb.lastFailureTime) > cb.timeout {
			cb.state = StateHalfOpen
		} else {
			return errors.New("circuit breaker is OPEN")
		}
	}

	// Execute function
	err := fn()

	if err != nil {
		cb.failureCount++
		cb.lastFailureTime = time.Now()

		if cb.failureCount >= cb.failureThreshold {
			cb.state = StateOpen
		}
		return err
	}

	// Success - reset failure count and close circuit
	cb.failureCount = 0
	cb.state = StateClosed
	return nil
}

func (cb *CircuitBreaker) GetState() CircuitBreakerState {
	cb.mutex.RLock()
	defer cb.mutex.RUnlock()
	return cb.state
}

func (cb *CircuitBreaker) GetFailureCount() int {
	cb.mutex.RLock()
	defer cb.mutex.RUnlock()
	return cb.failureCount
}
