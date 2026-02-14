# BackLynx v1.0 - Web UI Version

## ðŸŽ¯ Project Overview

**BackLynx Web UI** adalah versi berbasis web dari sistem backlink injection yang memungkinkan pengguna untuk mengupload file URLs.txt dan mengkonfigurasi target domain serta anchor text melalui interface yang user-friendly.

### Architecture
- **Go Layer**: Web server dan orchestrator untuk URL processing
- **Node.js Layer**: Browser automation dengan Puppeteer/Playwright
- **Web UI**: Modern HTML5 interface dengan TailwindCSS

---

## ðŸš€ Quick Start

### Prerequisites
- Docker Desktop 4.0+
- Docker Compose v2.0+

### Installation
```bash
# 1. Clone repository
git clone <repository-url>
cd "BackLynx (v1)"

# 2. Setup environment
cp .env.example .env
# Edit .env jika perlu (worker count, timeout, dll)

# 3. Deploy
docker-compose up -d
```

### Access Web UI
Buka browser anda dan akses: **http://localhost:8080**

---

## ðŸ“ Project Structure

```
BackLynx (v1)/
â”œâ”€â”€ web/                   # Web UI files
â”‚   â””â”€â”€ index.html        # Main web interface
â”œâ”€â”€ go/                    # Go Web Server & Orchestrator
â”‚   â”œâ”€â”€ main.go           # Main application with web API
â”‚   â”œâ”€â”€ Dockerfile
â”‚   â””â”€â”€ go.mod
â”œâ”€â”€ nodejs/                # Node.js Browser Engine
â”œâ”€â”€ docker-compose.yml      # Docker orchestration
â””â”€â”€ .env.example          # Environment template
```

---

## ðŸ”§ Web UI Usage

### 1. Upload URLs
- Click "Choose File" atau drag & drop file URLs.txt
- File harus berformat .txt dengan satu URL per baris
- Lines yang dimulai dengan # akan diabaikan

### 2. Configuration
- **Target Domain**: Masukkan domain tujuan backlink (contoh: https://yourdomain.com)
- **Anchor Text**: Masukkan teks anchor untuk backlink (contoh: SEO Services)

### 3. Start Processing
- Klik tombol "Start Processing" untuk memulai
- Monitor progress secara real-time
- Lihat statistik processed, success, dan failed

### 4. Download Results
- Setelah processing selesai, klik "Download CSV Results"
- File CSV berisi semua hasil dengan format:
  - timestamp, url, anchor, target_domain, status, response_time

---

## ðŸ“Š API Endpoints

- **Web UI**: `http://localhost:8080`
- **API Status**: `GET /api/v1/status`
- **Process URLs**: `POST /api/v1/process`
- **Get Results**: `GET /api/v1/results`
- **Export CSV**: `GET /api/v1/export`

### API Request Example
```json
POST /api/v1/process
{
  "urls": [
    "https://example1.com",
    "https://example2.com"
  ],
  "targetDomain": "https://yourdomain.com",
  "anchorText": "SEO Services"
}
```

---

## ï¿½ï¸ Features

### Web Interface
- âœ… Drag & drop file upload
- âœ… Real-time progress monitoring
- âœ… Responsive design
- âœ… Modern UI dengan TailwindCSS
- âœ… CSV export functionality

### Core Functionality
- âœ… Smart Backlink Injection
- âœ… Anti-Detection Systems
- âœ… Concurrent Processing (1000+ URLs)
- âœ… Rule-based Comment Generation (non-AI)
- âœ… Proxy Rotation Support
- âœ… In-memory processing (no database)

### Privacy & Security
- âœ… No data persistence
- âœ… In-memory processing only
- âœ… Results cleared after each session
- âœ… No user data storage

---

## ðŸ“ˆ Performance Targets

- **Success Rate**: 30-50% dari 1000 URLs
- **Processing Time**: 1-4 hours total
- **Concurrent URLs**: 1000+ simultaneous
- **Memory Usage**: Optimized per worker

---

## ðŸ” Monitoring & Debugging

### Web Interface Monitoring
- Real-time progress bar
- Live statistics (processed, success, failed)
- Status updates every 2 seconds

### Log Monitoring
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f go-orchestrator
docker-compose logs -f nodejs-workers
```

---

## ðŸš¨ Troubleshooting

### Common Issues
1. **Docker not running**: Start Docker Desktop
2. **Port conflicts**: Check ports 8080 and 6379
3. **File upload fails**: Ensure file is .txt format
4. **Processing stuck**: Check logs for errors

### Debug Mode
```bash
# Run with debug logs
LOG_LEVEL=debug docker-compose up
```

---

## ï¿½ Support

### Web UI Issues
- Check browser console for JavaScript errors
- Verify file format (.txt with valid URLs)
- Ensure all fields are filled before starting

### System Issues
- Check Docker logs for service errors
- Verify environment variables in .env
- Ensure sufficient system resources

---

**BackLynx v1.0 Web UI** - Professional backlink injection system with modern web interface.


