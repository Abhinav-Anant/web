#!/bin/bash

# =============================================================================
# ControlD Manager - One-Command Deployment Script
# Usage: sudo bash deploy.sh
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/var/log/controld-deploy.log"
mkdir -p /var/log

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  INFO: $1${NC}" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

# =============================================================================
# STEP 1: Install Dependencies
# =============================================================================
log "Step 1/10: Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq docker.io docker-compose git curl openssl ufw nginx certbot python3-certbot-nginx

# Start and enable Docker
systemctl start docker
systemctl enable docker --quiet

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>/dev/null
apt-get install -y -qq nodejs

info "Dependencies installed successfully"

# =============================================================================
# STEP 2: Clone/Update Repository
# =============================================================================
PROJECT_DIR="/opt/controld-manager"
log "Step 2/10: Setting up project directory..."

if [ -d "$PROJECT_DIR/.git" ]; then
    info "Updating existing repository..."
    cd "$PROJECT_DIR"
    git pull origin main
else
    info "Cloning repository..."
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    git clone https://github.com/Abhinav-Anant/web.git .
fi

# =============================================================================
# STEP 3: Generate Secure Secrets
# =============================================================================
log "Step 3/10: Generating secure secrets..."

# Generate random secrets
JWT_SECRET=$(openssl rand -base64 32)
DB_PASSWORD=$(openssl rand -base64 16)

# Backup existing files if they exist
if [ -f docker-compose.yml ]; then
    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d)
fi

if [ -f backend/.env ]; then
    cp backend/.env backend/.env.backup.$(date +%Y%m%d)
fi

# Update docker-compose.yml
sed -i "s/your_strong_password/$DB_PASSWORD/g" docker-compose.yml
sed -i "s/your-super-secret-jwt-key-change-this-in-production/$JWT_SECRET/g" docker-compose.yml

# Update backend/.env
sed -i "s/your_strong_password/$DB_PASSWORD/g" backend/.env
sed -i "s/your-super-secret-jwt-key-change-this-in-production/$JWT_SECRET/g" backend/.env

info "Secrets generated and configured"

# =============================================================================
# STEP 4: Database Setup
# =============================================================================
log "Step 4/10: Setting up database..."

cd "$PROJECT_DIR/backend"

# Install dependencies
npm install --silent --no-progress

# Generate Prisma client
npx prisma generate

info "Database setup complete"

# =============================================================================
# STEP 5: Create Admin User (Interactive)
# =============================================================================
log "Step 5/10: Creating admin account..."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 CREATE ADMIN ACCOUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Function to read password without echoing
read_password() {
    local password=""
    local prompt="$1"
    while IFS= read -r -s -n1 char; do
        [[ -z $char ]] && { printf '\n'; break; }
        if [[ $char == $'\x7f' ]]; then
            if [[ -n $password ]]; then
                password="${password%?}"
                printf '\b \b'
            fi
        else
            password+="$char"
            printf '*'
        fi
    done
    echo "$password"
}

# Get admin password
while true; do
    echo -n "Enter desired admin password: "
    ADMIN_PASS=$(read_password)
    
    if [ ${#ADMIN_PASS} -lt 8 ]; then
        warn "Password must be at least 8 characters. Please try again."
        continue
    fi
    
    echo -n "Confirm password: "
    ADMIN_PASS_CONFIRM=$(read_password)
    
    if [ "$ADMIN_PASS" = "$ADMIN_PASS_CONFIRM" ]; then
        break
    else
        warn "Passwords do not match. Please try again."
    fi
done

echo ""

# Create admin user
node -e "
const prisma = new (require('@prisma/client').PrismaClient)();
const bcrypt = require('bcryptjs');

(async () => {
  try {
    // Check if admin already exists
    const existing = await prisma.admin.findUnique({ where: { username: 'admin' } });
    if (existing) {
      console.log('Admin user already exists. Skipping creation.');
      return;
    }
    
    const hashedPassword = await bcrypt.hash('$ADMIN_PASS', 12);
    await prisma.admin.create({
      data: {
        username: 'admin',
        passwordHash: hashedPassword
      }
    });
    console.log('Admin account created successfully');
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  } finally {
    await prisma.\$disconnect();
  }
})()
"

info "Admin account created"

# =============================================================================
# STEP 6: Build Docker Containers
# =============================================================================
log "Step 6/10: Building Docker containers..."

cd "$PROJECT_DIR"
docker-compose build --no-cache

# =============================================================================
# STEP 7: Start Services
# =============================================================================
log "Step 7/10: Starting Docker services..."

docker-compose down --remove-orphans 2>/dev/null || true
docker-compose up -d

# Wait for services to be ready
info "Waiting for services to start (30 seconds)..."
sleep 30

# Check container status
if ! docker-compose ps | grep -q "Up"; then
    error "Services failed to start. Check logs with: docker-compose logs"
fi

log "Services started successfully"

# =============================================================================
# STEP 8: Setup Nginx
# =============================================================================
log "Step 8/10: Configuring Nginx..."

# Stop Nginx if running on host
systemctl stop nginx 2>/dev/null || true

# Create Nginx config
cat > /etc/nginx/sites-available/controld-manager << 'NGINX_EOF'
server {
    listen 80;
    server_name control.asmitainfocom.in;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /api/auth/login {
        limit_req zone=login burst=5 nodelay;
        proxy_pass http://localhost:3000/api/auth/login;
        # ... same headers as above ...
    }

    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://localhost:3000/api/;
        # ... same headers as above ...
    }
}
NGINX_EOF

# Enable site
ln -sf /etc/nginx/sites-available/controld-manager /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx config
nginx -t

log "Nginx configured successfully"

# =============================================================================
# STEP 9: Setup SSL with Let's Encrypt
# =============================================================================
log "Step 9/10: Obtaining SSL certificate..."

# Start Nginx temporarily for certbot
systemctl start nginx

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📧 LET'S ENCRYPT SSL SETUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Enter your email address for SSL registration: " ADMIN_EMAIL
echo ""

# Obtain SSL certificate
certbot --nginx -d control.asmitainfocom.in --email "$ADMIN_EMAIL" --agree-tos --no-eff-email

# Enable auto-renewal
systemctl enable certbot.timer
systemctl start certbot.timer

log "SSL certificate installed and auto-renewal enabled"

# =============================================================================
# STEP 10: Configure Firewall
# =============================================================================
log "Step 10/10: Configuring UFW firewall..."

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (change 22 if needed)
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
echo "y" | ufw enable

ufw status verbose

# =============================================================================
# DEPLOYMENT COMPLETE
# =============================================================================
log "DEPLOYMENT SUCCESSFUL!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔥 CONTROL D MANAGER IS LIVE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 Customer Login: https://control.asmitainfocom.in"
echo "🔧 Admin Panel: Open admin.html on your local machine"
echo "⚡ API Endpoint: https://control.asmitainfocom.in/api"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  SAVE THESE CREDENTIALS - THIS IS THE ONLY TIME THEY ARE SHOWN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👤 Admin Username: admin"
echo "🔑 Admin Password: $ADMIN_PASS"
echo "🗝️  JWT Secret: $JWT_SECRET"
echo "🔐 DB Password: $DB_PASSWORD"
echo ""
echo "💾 These credentials have been saved to: /root/controld-credentials.txt"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Save credentials to file
cat > /root/controld-credentials.txt << EOF
ControlD Manager Deployment - $(date)
=====================================
Admin Username: admin
Admin Password: $ADMIN_PASS
JWT Secret: $JWT_SECRET
Database Password: $DB_PASSWORD
Project Directory: $PROJECT_DIR
=====================================
EOF

chmod 600 /root/controld-credentials.txt

info "Installation complete! Log file: $LOG_FILE"

# Create management commands
cat > /usr/local/bin/controld-manager << 'MANAGER_EOF'
#!/bin/bash
case "$1" in
    status)
        cd /opt/controld-manager && docker-compose ps
        ;;
    logs)
        cd /opt/controld-manager && docker-compose logs -f --tail=100 backend
        ;;
    restart)
        cd /opt/controld-manager && docker-compose restart
        echo "Services restarted"
        ;;
    stop)
        cd /opt/controld-manager && docker-compose down
        echo "Services stopped"
        ;;
    start)
        cd /opt/controld-manager && docker-compose up -d
        echo "Services started"
        ;;
    update)
        cd /opt/controld-manager
        git pull origin main
        docker-compose up --build -d
        echo "Updated and rebuilt"
        ;;
    backup)
        BACKUP_FILE="/backup/controld-backup-$(date +%Y%m%d-%H%M%S).sql"
        mkdir -p /backup
        cd /opt/controld-manager && docker-compose exec -T postgres pg_dump -U controld_user controldb > "$BACKUP_FILE"
        echo "Backup created: $BACKUP_FILE"
        ;;
    *)
        echo "Usage: controld-manager {status|logs|restart|stop|start|update|backup}"
        exit 1
        ;;
esac
MANAGER_EOF

chmod +x /usr/local/bin/controld-manager

# Final check
docker-compose ps

echo ""
log "All set! Your ControlD Manager is ready to use."
echo "Run 'sudo controld-manager status' to check services."
echo "Run 'sudo controld-manager logs' to view logs."
