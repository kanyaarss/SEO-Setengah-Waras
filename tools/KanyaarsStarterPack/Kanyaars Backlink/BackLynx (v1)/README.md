# BackLynx v1.0 - Web UI Version

## 🎯 Project Overview

**BackLynx Web UI** adalah versi berbasis web dari sistem backlink injection yang memungkinkan pengguna untuk mengupload file URLs.txt dan mengkonfigurasi target domain serta anchor text melalui interface yang user-friendly.

### Architecture
- **Go Layer**: Web server dan orchestrator untuk URL processing
- **Node.js Layer**: Browser automation dengan Puppeteer/Playwright
- **Python Layer**: AI-powered content generation dan intelligence
- **Web UI**: Modern HTML5 interface dengan TailwindCSS

---

## 🚀 Quick Start

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
# Edit .env dengan konfigurasi Anda (OPENAI_API_KEY, dll)

# 3. Deploy
docker-compose up -d
```

### Access Web UI
Buka browser anda dan akses: **http://localhost:8080**

---

## 📁 Project Structure

```
BackLynx (v1)/
├── web/                   # Web UI files
│   └── index.html        # Main web interface
├── go/                    # Go Web Server & Orchestrator
│   ├── main.go           # Main application with web API
│   ├── Dockerfile
│   └── go.mod
├── nodejs/                # Node.js Browser Engine
├── python/                # Python Intelligence Engine
├── docker-compose.yml      # Docker orchestration
└── .env.example          # Environment template
```

---

## 🔧 Web UI Usage

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

## 📊 API Endpoints

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

## �️ Features

### Web Interface
- ✅ Drag & drop file upload
- ✅ Real-time progress monitoring
- ✅ Responsive design
- ✅ Modern UI dengan TailwindCSS
- ✅ CSV export functionality

### Core Functionality
- ✅ Smart Backlink Injection
- ✅ Anti-Detection Systems
- ✅ Concurrent Processing (1000+ URLs)
- ✅ AI Comment Generation
- ✅ Proxy Rotation Support
- ✅ In-memory processing (no database)

### Privacy & Security
- ✅ No data persistence
- ✅ In-memory processing only
- ✅ Results cleared after each session
- ✅ No user data storage

---

## 📈 Performance Targets

- **Success Rate**: 30-50% dari 1000 URLs
- **Processing Time**: 1-4 hours total
- **Concurrent URLs**: 1000+ simultaneous
- **Memory Usage**: Optimized per worker

---

## 🔍 Monitoring & Debugging

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
docker-compose logs -f python-ai
```

---

## 🚨 Troubleshooting

### Common Issues
1. **Docker not running**: Start Docker Desktop
2. **Port conflicts**: Check ports 8080, 5000, 6379
3. **File upload fails**: Ensure file is .txt format
4. **Processing stuck**: Check logs for errors

### Debug Mode
```bash
# Run with debug logs
LOG_LEVEL=debug docker-compose up
```

---

## � Support

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
