const Redis = require('redis');
const axios = require('axios');

class NodeJSWorker {
    constructor() {
        this.redis = null;
        this.isRunning = false;
        this.config = this.loadConfig();
    }

    loadConfig() {
        return {
            redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
            goHost: process.env.GO_HOST || 'go-orchestrator',
            goPort: process.env.GO_PORT || '8080',
            pythonHost: process.env.PYTHON_HOST || 'python-ai',
            pythonPort: process.env.PYTHON_PORT || '5000'
        };
    }

    async initialize() {
        try {
            // Initialize Redis
            this.redis = Redis.createClient({ url: this.config.redisUrl });
            await this.redis.connect();
            console.log('Connected to Redis');
            
            console.log('NodeJS Worker initialized successfully (simplified mode)');
        } catch (error) {
            console.error('Failed to initialize NodeJS Worker:', error);
            throw error;
        }
    }

    async start() {
        if (this.isRunning) {
            console.log('Worker is already running');
            return;
        }

        try {
            await this.initialize();
            this.isRunning = true;
            console.log('NodeJS Worker started successfully (simplified mode)');
            
            // Start simple health check loop
            this.startHealthCheck();
        } catch (error) {
            console.error('Failed to start NodeJS Worker:', error);
            throw error;
        }
    }

    async startHealthCheck() {
        setInterval(async () => {
            try {
                // Simple health check - ping Redis
                await this.redis.ping();
                console.log('Health check passed');
            } catch (error) {
                console.error('Health check failed:', error);
            }
        }, 30000); // Every 30 seconds
    }

    async stop() {
        this.isRunning = false;
        if (this.redis) {
            await this.redis.disconnect();
        }
        console.log('NodeJS Worker stopped');
    }
}

// Start the worker
const worker = new NodeJSWorker();

worker.start().catch(console.error);

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('Received SIGINT, shutting down gracefully...');
    await worker.stop();
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('Received SIGTERM, shutting down gracefully...');
    await worker.stop();
    process.exit(0);
});
            console.log('Connected to Redis');

            // Initialize browser worker
            this.browserWorker = new BrowserWorker(this.config);
            await this.browserWorker.initialize();

            // Initialize form handler
            this.formHandler = new FormHandler();

            // Initialize captcha detector
            this.captchaDetector = new CaptchaDetector();

            // Initialize stealth manager
            this.stealthManager = new StealthManager();

            this.isRunning = true;
            console.log('Node.js Worker initialized successfully');

        } catch (error) {
            console.error('Failed to initialize Node.js Worker:', error);
            throw error;
        }
    }

    async start() {
        if (!this.isRunning) {
            await this.initialize();
        }

        console.log('Starting URL processing loop...');
        
        while (this.isRunning) {
            try {
                // Get task from queue
                const taskData = await this.redis.brPop('url_queue', 10);
                
                if (!taskData) {
                    continue;
                }

                const task = JSON.parse(taskData.element);
                console.log(`Processing URL: ${task.url}`);

                // Process the URL
                const result = await this.processURL(task);

                // Send result back
                await this.redis.lPush('result_queue', JSON.stringify(result));

                console.log(`Completed processing: ${task.url} - ${result.status}`);

            } catch (error) {
                console.error('Error in processing loop:', error);
                await this.sleep(5000); // Wait before retrying
            }
        }
    }

    async processURL(task) {
        const startTime = Date.now();
        let result = {
            timestamp: new Date().toISOString(),
            url: task.url,
            anchor: task.anchor,
            target_domain: task.target_domain,
            status: 'failed',
            response_time: 0,
            error: null
        };

        try {
            // Get AI-generated content
            const content = await this.getGeneratedContent(task);
            
            // Setup browser with stealth
            const page = await this.browserWorker.getNewPage();
            await this.stealthManager.applyStealth(page);

            // Navigate to URL
            await page.goto(task.url, { 
                waitUntil: 'networkidle2',
                timeout: this.config.timeout 
            });

            // Check for CAPTCHA
            const hasCaptcha = await this.captchaDetector.detect(page);
            if (hasCaptcha) {
                throw new Error('CAPTCHA detected - skipping');
            }

            // Find and fill forms
            const forms = await this.formHandler.findForms(page);
            if (forms.length === 0) {
                throw new Error('No forms found on page');
            }

            // Try to submit the first suitable form
            const submitted = await this.formHandler.submitForm(page, forms[0], {
                content: content,
                anchor: task.anchor,
                targetDomain: task.target_domain
            });

            if (submitted) {
                result.status = 'success';
                console.log(`Successfully submitted backlink to: ${task.url}`);
            } else {
                result.error = 'Form submission failed';
            }

            await page.close();

        } catch (error) {
            result.error = error.message;
            console.error(`Failed to process ${task.url}:`, error.message);
        }

        result.response_time = (Date.now() - startTime) / 1000;
        return result;
    }

    async getGeneratedContent(task) {
        try {
            const response = await axios.post(`http://${this.config.pythonHost}:${this.config.pythonPort}/generate`, {
                url: task.url,
                anchor: task.anchor,
                targetDomain: task.target_domain
            }, {
                timeout: 10000
            });

            return response.data.content;
        } catch (error) {
            console.error('Failed to get AI content:', error.message);
            // Fallback to simple template
            return `Great article! Check out ${task.anchor} at ${task.target_domain} for more information.`;
        }
    }

    async shutdown() {
        console.log('Shutting down Node.js Worker...');
        this.isRunning = false;

        if (this.browserWorker) {
            await this.browserWorker.shutdown();
        }

        if (this.redis) {
            await this.redis.quit();
        }

        console.log('Node.js Worker shutdown complete');
    }

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// Handle graceful shutdown
const worker = new NodeJSWorker();

process.on('SIGINT', async () => {
    console.log('Received SIGINT, shutting down gracefully...');
    await worker.shutdown();
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('Received SIGTERM, shutting down gracefully...');
    await worker.shutdown();
    process.exit(0);
});

// Start the worker
(async () => {
    try {
        await worker.start();
    } catch (error) {
        console.error('Failed to start worker:', error);
        process.exit(1);
    }
})();
