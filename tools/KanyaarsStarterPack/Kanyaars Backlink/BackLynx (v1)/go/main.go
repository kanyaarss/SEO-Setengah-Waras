package main

import (
	"bytes"
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/sirupsen/logrus"
)

type Config struct {
	RedisURL          string `json:"redis_url"`
	GoPort            string `json:"go_port"`
	GoWorkerCount     int    `json:"go_worker_count"`
	MaxConcurrentURLs int    `json:"max_concurrent_urls"`
	BatchSize         int    `json:"batch_size"`
	RetryAttempts     int    `json:"retry_attempts"`
	TimeoutSeconds    int    `json:"timeout_seconds"`
}

type URLTask struct {
	ID           string    `json:"id"`
	URL          string    `json:"url"`
	Anchor       string    `json:"anchor"`
	TargetDomain string    `json:"target_domain"`
	Status       string    `json:"status"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
	ResponseTime float64   `json:"response_time"`
	Error        string    `json:"error,omitempty"`
}

type ProcessRequest struct {
	URLs         []string `json:"urls"`
	TargetDomain string   `json:"targetDomain"`
	AnchorText   string   `json:"anchorText"`
}

type ProcessStatus struct {
	Status    string `json:"status"`
	Processed int    `json:"processed"`
	Success   int    `json:"success"`
	Failed    int    `json:"failed"`
	Total     int    `json:"total"`
}

type Result struct {
	Timestamp    time.Time `json:"timestamp"`
	URL          string    `json:"url"`
	Anchor       string    `json:"anchor"`
	TargetDomain string    `json:"target_domain"`
	Status       string    `json:"status"`
	ResponseTime float64   `json:"response_time"`
	Error        string    `json:"error,omitempty"`
}

var (
	config        Config
	logger        *logrus.Logger
	redisClient   *redis.Client
	results       []Result
	resultsMutex  sync.RWMutex
	processStatus ProcessStatus
	statusMutex   sync.RWMutex
	logMessages   []string
	logMutex      sync.RWMutex
)

const controlChannel = "backlynx:control"

func init() {
	logger = logrus.New()
	logger.SetFormatter(&logrus.JSONFormatter{})
	logger.SetLevel(logrus.InfoLevel)

	// Add custom hook for storing logs
	logger.AddHook(&CustomLogHook{})
}

// CustomLogHook stores log messages in memory
type CustomLogHook struct{}

func (hook *CustomLogHook) Fire(entry *logrus.Entry) error {
	logMutex.Lock()
	defer logMutex.Unlock()

	timestamp := entry.Time.Format("2006-01-02 15:04:05")
	level := strings.ToUpper(entry.Level.String())
	message := fmt.Sprintf("[%s] %s: %s", timestamp, level, entry.Message)

	// Add fields if present
	if len(entry.Data) > 0 {
		for k, v := range entry.Data {
			message += fmt.Sprintf(" %s=%v", k, v)
		}
	}

	logMessages = append(logMessages, message)

	// Keep only last 1000 log messages
	if len(logMessages) > 1000 {
		logMessages = logMessages[len(logMessages)-1000:]
	}

	return nil
}

func (hook *CustomLogHook) Levels() []logrus.Level {
	return logrus.AllLevels
}

func getRecentLogs() []string {
	logMutex.RLock()
	defer logMutex.RUnlock()

	// Return last 50 log messages
	if len(logMessages) <= 50 {
		return logMessages
	}
	return logMessages[len(logMessages)-50:]
}

func loadConfig() error {
	config = Config{
		RedisURL:          getEnv("REDIS_URL", "redis://localhost:6379"),
		GoPort:            getEnv("GO_PORT", "8080"),
		GoWorkerCount:     getEnvAsInt("GO_WORKER_COUNT", 100),
		MaxConcurrentURLs: getEnvAsInt("MAX_CONCURRENT_URLS", 1000),
		BatchSize:         getEnvAsInt("BATCH_SIZE", 50),
		RetryAttempts:     getEnvAsInt("RETRY_ATTEMPTS", 3),
		TimeoutSeconds:    getEnvAsInt("TIMEOUT_SECONDS", 30),
	}
	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func initRedis() error {
	opt, err := redis.ParseURL(config.RedisURL)
	if err != nil {
		return fmt.Errorf("failed to parse redis URL: %v", err)
	}

	redisClient = redis.NewClient(opt)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := redisClient.Ping(ctx).Err(); err != nil {
		return fmt.Errorf("failed to connect to redis: %v", err)
	}

	logger.Info("Connected to Redis")
	return nil
}

func initResults() error {
	resultsMutex.Lock()
	defer resultsMutex.Unlock()
	results = []Result{}
	logger.Info("Results initialized in memory")
	return nil
}

func loadURLsFromRequest(req ProcessRequest) ([]URLTask, error) {
	var tasks []URLTask

	for i, url := range req.URLs {
		url = strings.TrimSpace(url)
		if url == "" || strings.HasPrefix(url, "#") {
			continue
		}

		task := URLTask{
			ID:           fmt.Sprintf("task_%d", i),
			URL:          url,
			Anchor:       req.AnchorText,
			TargetDomain: req.TargetDomain,
			Status:       "pending",
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		}

		tasks = append(tasks, task)
	}

	logger.Infof("Loaded %d URLs from request", len(tasks))
	return tasks, nil
}

func enqueueURLs(ctx context.Context, tasks []URLTask) error {
	for _, task := range tasks {
		taskJSON, err := json.Marshal(task)
		if err != nil {
			logger.Errorf("Failed to marshal task %s: %v", task.ID, err)
			continue
		}

		if err := redisClient.LPush(ctx, "url_queue", taskJSON).Err(); err != nil {
			return fmt.Errorf("failed to enqueue task %s: %v", task.ID, err)
		}
	}

	logger.Infof("Enqueued %d tasks to Redis queue", len(tasks))
	return nil
}

func publishControl(action string) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	payload := fmt.Sprintf(`{"action":"%s","ts":"%s"}`, action, time.Now().Format(time.RFC3339))
	if err := redisClient.Publish(ctx, controlChannel, payload).Err(); err != nil {
		logger.Errorf("Failed to publish control action %s: %v", action, err)
		return
	}
	logger.Infof("Published control action: %s", action)
}

func processResults(ctx context.Context) error {
	type resultPayload struct {
		Timestamp       time.Time `json:"timestamp"`
		URL             string    `json:"url"`
		Anchor          string    `json:"anchor"`
		TargetDomain    string    `json:"target_domain"`
		TargetDomainAlt string    `json:"targetDomain"`
		Status          string    `json:"status"`
		ResponseTime    float64   `json:"response_time"`
		Error           string    `json:"error,omitempty"`
	}

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			resultJSON, err := redisClient.BRPop(ctx, 0, "result_queue").Result()
			if err != nil {
				if err == redis.Nil {
					continue
				}
				logger.Errorf("Failed to pop result from queue: %v", err)
				continue
			}

			if len(resultJSON) < 2 {
				continue
			}

			var payload resultPayload
			if err := json.Unmarshal([]byte(resultJSON[1]), &payload); err != nil {
				logger.Errorf("Failed to unmarshal result: %v", err)
				continue
			}

			targetDomain := payload.TargetDomain
			if targetDomain == "" {
				targetDomain = payload.TargetDomainAlt
			}

			result := Result{
				Timestamp:    payload.Timestamp,
				URL:          payload.URL,
				Anchor:       payload.Anchor,
				TargetDomain: targetDomain,
				Status:       payload.Status,
				ResponseTime: payload.ResponseTime,
				Error:        payload.Error,
			}

			statusMutex.RLock()
			shouldProcess := processStatus.Status == "processing"
			statusMutex.RUnlock()
			if !shouldProcess {
				logger.Infof("Dropped late result for %s because process is not active", result.URL)
				continue
			}

			// Save result to memory
			saveResultToMemory(result)
			updateProcessStatus(result)
		}
	}
}

func saveResultToMemory(result Result) {
	resultsMutex.Lock()
	defer resultsMutex.Unlock()
	results = append(results, result)
	if result.Status == "failed" && result.Error != "" {
		logger.Infof("Saved result to memory: %s - %s (error=%s)", result.URL, result.Status, result.Error)
	} else {
		logger.Infof("Saved result to memory: %s - %s", result.URL, result.Status)
	}
}

func updateProcessStatus(result Result) {
	statusMutex.Lock()
	defer statusMutex.Unlock()
	processStatus.Processed++
	if result.Status == "success" {
		processStatus.Success++
	} else {
		processStatus.Failed++
	}

	if processStatus.Processed >= processStatus.Total {
		processStatus.Status = "completed"
	}
}

func startAPI() {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	// Health check endpoint
	r.GET("/api/v1/status", func(c *gin.Context) {
		statusMutex.RLock()
		defer statusMutex.RUnlock()

		c.JSON(http.StatusOK, gin.H{
			"status":     processStatus.Status,
			"timestamp":  time.Now(),
			"queue_size": getQueueSize(),
			"processed":  processStatus.Processed,
			"success":    processStatus.Success,
			"failed":     processStatus.Failed,
			"total":      processStatus.Total,
		})
	})

	// Serve web UI
	r.Static("/static", "./web")
	r.GET("/", func(c *gin.Context) {
		c.File("./web/index.html")
	})

	// Process URLs from web request
	r.POST("/api/v1/process", func(c *gin.Context) {
		var req ProcessRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if strings.TrimSpace(req.TargetDomain) == "" || strings.TrimSpace(req.AnchorText) == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "targetDomain and anchorText are required"})
			return
		}

		// Clear previous results
		resultsMutex.Lock()
		results = []Result{}
		resultsMutex.Unlock()

		// Load URLs from request
		tasks, err := loadURLsFromRequest(req)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		// Initialize process status based on valid tasks.
		statusMutex.Lock()
		processStatus = ProcessStatus{
			Status:    "processing",
			Processed: 0,
			Success:   0,
			Failed:    0,
			Total:     len(tasks),
		}
		if len(tasks) == 0 {
			processStatus.Status = "completed"
		}
		statusMutex.Unlock()

		// Ensure workers are in active mode before enqueueing new tasks.
		publishControl("start")

		// Enqueue URLs to Redis
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		if err := enqueueURLs(ctx, tasks); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Processing started", "total_urls": len(tasks)})
	})

	// Stop processing, export current results, and clear queue/cache.
	r.POST("/api/v1/stop", func(c *gin.Context) {
		// Tell workers to abort active processing first.
		publishControl("stop")

		csvData := getCSVSnapshot()
		clearRuntimeState()

		c.Header("Content-Type", "text/csv")
		c.Header("Content-Disposition", "attachment; filename=backlynx_results.csv")
		c.String(http.StatusOK, csvData)
	})

	// Get results endpoint
	r.GET("/api/v1/results", func(c *gin.Context) {
		resultsMutex.RLock()
		defer resultsMutex.RUnlock()
		c.JSON(http.StatusOK, results)
	})

	// Export CSV endpoint
	r.GET("/api/v1/export", func(c *gin.Context) {
		resultsMutex.RLock()
		defer resultsMutex.RUnlock()

		if len(results) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "No results to export"})
			return
		}

		csvData, err := buildCSVData(results)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("failed to build CSV: %v", err)})
			return
		}

		c.Header("Content-Type", "text/csv")
		c.Header("Content-Disposition", "attachment; filename=backlynx_results.csv")
		c.String(http.StatusOK, csvData)
	})

	// Simple logs endpoint
	r.GET("/api/v1/logs", func(c *gin.Context) {
		logMutex.RLock()
		defer logMutex.RUnlock()

		// Return last 20 log messages as JSON
		var recentLogs []string
		if len(logMessages) <= 20 {
			recentLogs = make([]string, len(logMessages))
			copy(recentLogs, logMessages)
		} else {
			recentLogs = make([]string, 20)
			copy(recentLogs, logMessages[len(logMessages)-20:])
		}

		c.JSON(http.StatusOK, gin.H{
			"logs":  recentLogs,
			"total": len(logMessages),
		})
	})

	logger.Infof("Starting API server on port %s", config.GoPort)
	if err := r.Run(":" + config.GoPort); err != nil {
		logger.Fatalf("Failed to start API server: %v", err)
	}
}

func getQueueSize() int64 {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	size, err := redisClient.LLen(ctx, "url_queue").Result()
	if err != nil {
		logger.Errorf("Failed to get queue size: %v", err)
		return 0
	}
	return size
}

func getCSVSnapshot() string {
	resultsMutex.RLock()
	defer resultsMutex.RUnlock()

	csvData, err := buildCSVData(results)
	if err != nil {
		logger.Errorf("Failed to build CSV snapshot: %v", err)
		return "timestamp,url,anchor,target_domain,status,response_time,error\n"
	}
	return csvData
}

func clearRuntimeState() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := redisClient.Del(ctx, "url_queue", "result_queue", "backlynx:queue:error").Err(); err != nil {
		logger.Errorf("Failed to clear Redis queues: %v", err)
	}

	resultsMutex.Lock()
	results = []Result{}
	resultsMutex.Unlock()

	statusMutex.Lock()
	processStatus = ProcessStatus{
		Status:    "idle",
		Processed: 0,
		Success:   0,
		Failed:    0,
		Total:     0,
	}
	statusMutex.Unlock()
}

func exportToCSV() error {
	resultsMutex.RLock()
	defer resultsMutex.RUnlock()

	if len(results) == 0 {
		return fmt.Errorf("no results to export")
	}

	if _, err := buildCSVData(results); err != nil {
		return fmt.Errorf("failed to build CSV data: %v", err)
	}

	logger.Infof("Generated CSV with %d results", len(results))
	return nil
}

func buildCSVData(input []Result) (string, error) {
	var buf bytes.Buffer
	writer := csv.NewWriter(&buf)

	header := []string{"timestamp", "url", "anchor", "target_domain", "status", "response_time", "error"}
	if err := writer.Write(header); err != nil {
		return "", err
	}

	for _, result := range input {
		row := []string{
			result.Timestamp.Format(time.RFC3339),
			result.URL,
			result.Anchor,
			result.TargetDomain,
			result.Status,
			fmt.Sprintf("%.2f", result.ResponseTime),
			result.Error,
		}
		if err := writer.Write(row); err != nil {
			return "", err
		}
	}

	writer.Flush()
	if err := writer.Error(); err != nil {
		return "", err
	}

	return buf.String(), nil
}

func main() {
	if err := loadConfig(); err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	if err := initRedis(); err != nil {
		log.Fatalf("Failed to initialize Redis: %v", err)
	}

	if err := initResults(); err != nil {
		log.Fatalf("Failed to initialize results: %v", err)
	}

	// Initialize process status
	processStatus = ProcessStatus{
		Status:    "idle",
		Processed: 0,
		Success:   0,
		Failed:    0,
		Total:     0,
	}

	// Start background workers
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var wg sync.WaitGroup

	// Start result processor
	wg.Add(1)
	go func() {
		defer wg.Done()
		if err := processResults(ctx); err != nil {
			logger.Errorf("Result processor error: %v", err)
		}
	}()

	// Start periodic CSV export
	wg.Add(1)
	go func() {
		defer wg.Done()
		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if err := exportToCSV(); err != nil {
					logger.Errorf("CSV export error: %v", err)
				}
			}
		}
	}()

	// Start API server
	go startAPI()

	logger.Info("BackLynx Go Orchestrator started successfully")

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	logger.Info("Shutting down gracefully...")
	cancel()
	wg.Wait()
	logger.Info("Shutdown complete")
}
