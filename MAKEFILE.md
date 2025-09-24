# Makefile Commands Guide

This Makefile provides easy commands for development, testing, and deployment of the Sub-Balance Demo project.

## 🚀 Quick Start Commands

### Essential Commands
```bash
make help          # Show all available commands
make setup         # Setup environment and dependencies
make run           # Start the application
make test          # Run TPS performance tests
```

### Development Workflow
```bash
make dev-setup     # Complete development setup (Docker + Environment + Test Data)
make dev-full      # Setup and run application
make dev-workflow  # Complete development workflow
```

## 📋 Command Categories

### 🔧 Setup & Installation
| Command | Description |
|---------|-------------|
| `make setup` | Setup environment and dependencies |
| `make install` | Install Go dependencies |
| `make deps` | Alias for install |
| `make check` | Check if all dependencies are available |

### 🚀 Application Control
| Command | Description |
|---------|-------------|
| `make run` | Run the application |
| `make start` | Alias for run |
| `make dev` | Run in development mode |
| `make stop` | Stop the application |
| `make build` | Build the application |
| `make prod-build` | Build for production |
| `make prod-run` | Build and run for production |

### 🐳 Docker Commands
| Command | Description |
|---------|-------------|
| `make docker-up` | Start Docker services (PostgreSQL, Redis) |
| `make docker-down` | Stop Docker services |
| `make docker-restart` | Restart Docker services |
| `make logs` | Show application logs |
| `make logs-db` | Show database logs |
| `make logs-redis` | Show Redis logs |

### 🧪 Testing Commands
| Command | Description |
|---------|-------------|
| `make test` | Run TPS performance tests |
| `make test-setup` | Setup test data |
| `make test-status` | Check test account status |
| `make test-clean` | Clean test data |
| `make quick-test` | Quick test setup and run |

### 🏥 Health & Monitoring
| Command | Description |
|---------|-------------|
| `make health` | Check application health |
| `make health-detailed` | Check detailed application health |
| `make balance` | Check test account balance |
| `make pending` | Check pending transactions |
| `make monitor` | Monitor application metrics |

### 🗄️ Database Commands
| Command | Description |
|---------|-------------|
| `make db-reset` | Reset database |
| `make db-migrate` | Run database migrations |

### 🧹 Cleanup Commands
| Command | Description |
|---------|-------------|
| `make clean` | Clean build artifacts |
| `make clean-reports` | Clean test reports |
| `make clean-all` | Clean everything including Docker |
| `make fresh` | Fresh start - clean everything and setup |

### ⚙️ Configuration & Info
| Command | Description |
|---------|-------------|
| `make config` | Show current configuration |
| `make env` | Show environment variables |
| `make version` | Show version information |
| `make targets` | Show all available targets |

### 🔍 Development Tools
| Command | Description |
|---------|-------------|
| `make lint` | Run linter |
| `make fmt` | Format code |
| `make coverage` | Run tests with coverage |
| `make benchmark` | Run benchmarks |
| `make security` | Run security checks |

## 🎯 Common Workflows

### 1. First Time Setup
```bash
make check          # Check dependencies
make docker-up      # Start Docker services
make setup          # Setup environment
make test-setup     # Setup test data
make run            # Start application
```

### 2. Daily Development
```bash
make dev-setup      # Complete setup
make run            # Start application
make test           # Run tests
make health         # Check health
```

### 3. Testing Workflow
```bash
make test-setup     # Setup test data
make test           # Run TPS tests
make test-status    # Check results
make clean-reports  # Clean old reports
```

### 4. Production Deployment
```bash
make prod-build     # Build for production
make prod-run       # Run production build
```

### 5. Troubleshooting
```bash
make health         # Check application health
make logs           # Check application logs
make logs-db        # Check database logs
make logs-redis     # Check Redis logs
make balance        # Check account balance
make pending        # Check pending transactions
```

## 🔧 Configuration

### Environment Variables
The Makefile uses these environment variables:
- `APP_NAME`: Application name (default: sub-balance-demo)
- `PORT`: Application port (default: 8080)
- `TEST_ACCOUNT`: Test account ID (default: ACC001)

### Custom Configuration
You can override defaults by setting environment variables:
```bash
export PORT=8081
export TEST_ACCOUNT=ACC002
make run
```

## 📊 Test Results

After running tests, check the results:
```bash
# View latest test report
ls -la reports/tps_complete_report_*.md | tail -1 | xargs cat

# View test logs
ls -la reports/tps_test_*.log | tail -1 | xargs tail -f
```

## 🚨 Troubleshooting

### Common Issues

1. **Dependencies not found**
   ```bash
   make check  # Check what's missing
   ```

2. **Docker services not running**
   ```bash
   make docker-up
   make logs-db    # Check database
   make logs-redis # Check Redis
   ```

3. **Application not responding**
   ```bash
   make health
   make logs
   ```

4. **Test data issues**
   ```bash
   make test-status
   make test-setup  # Recreate test data
   ```

## 💡 Tips

- Use `make help` to see all available commands
- Use `make dev-setup` for complete development environment
- Use `make quick-test` for fast testing
- Use `make fresh` to start completely clean
- Check `make version` for system information

## 🔗 Related Files

- `scripts/run-with-config.sh` - Application startup script
- `scripts/test-tps-complete.sh` - TPS testing script
- `scripts/setup-test-data.sh` - Test data setup script
- `scripts/setup-env.sh` - Environment setup script
- `environment.env` - Environment configuration
- `docker-compose.yml` - Docker services configuration
