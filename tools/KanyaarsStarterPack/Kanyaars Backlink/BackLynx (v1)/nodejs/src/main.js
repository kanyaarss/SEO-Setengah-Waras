const Redis = require('redis');
const axios = require('axios');
const { chromium } = require('playwright-core');
const UserAgent = require('user-agents');

class NodeJSWorker {
    constructor() {
        this.redis = null;
        this.control = null;
        this.browser = null;
        this.isRunning = false;
        this.config = this.loadConfig();
        this.processingCount = 0;
        this.maxConcurrent = 5;
        this.stopRequested = false;
        this.activePages = new Set();
    }

    loadConfig() {
        return {
            redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
            redisQueue: process.env.REDIS_QUEUE || 'url_queue',
            redisErrorQueue: process.env.REDIS_ERROR_QUEUE || 'backlynx:queue:error',
            redisResultQueue: process.env.REDIS_RESULT_QUEUE || 'result_queue',
            controlChannel: process.env.REDIS_CONTROL_CHANNEL || 'backlynx:control',
            goHost: process.env.GO_HOST || 'go-orchestrator',
            goPort: process.env.GO_PORT || '8080',
            headless: process.env.NODE_HEADLESS === 'true',
            maxConcurrent: parseInt(process.env.MAX_CONCURRENT_URLS) || 5
        };
    }

    async initialize() {
        try {
            // Initialize Redis
            this.redis = Redis.createClient({ url: this.config.redisUrl });
            await this.redis.connect();
            console.log('Connected to Redis');

            // Control channel listener for start/stop actions
            this.control = this.redis.duplicate();
            await this.control.connect();
            await this.control.subscribe(this.config.controlChannel, (message) => {
                this.handleControlMessage(message).catch((err) => {
                    console.error('Control handler failed:', err.message);
                });
            });
            console.log(`Subscribed to control channel: ${this.config.controlChannel}`);

            // Initialize Playwright browser
            this.browser = await chromium.launch({
                headless: this.config.headless,
                executablePath: '/usr/bin/chromium-browser',
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-accelerated-2d-canvas',
                    '--no-first-run',
                    '--no-zygote',
                    '--disable-gpu',
                    '--disable-extensions',
                    '--disable-background-timer-throttling',
                    '--disable-renderer-backgrounding',
                    '--disable-backgrounding-occluded-windows',
                    '--disable-features=TranslateUI',
                    '--disable-ipc-flooding-protection'
                ]
            });
            console.log('Browser initialized successfully');
            
            console.log('NodeJS Worker initialized successfully');
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
            this.maxConcurrent = this.config.maxConcurrent;
            console.log(`NodeJS Worker started with max ${this.maxConcurrent} concurrent tasks`);
            
            // Start queue processing
            this.startQueueProcessor();
            
            // Start health check
            this.startHealthCheck();
        } catch (error) {
            console.error('Failed to start NodeJS Worker:', error);
            throw error;
        }
    }

    async startQueueProcessor() {
        console.log('Starting queue processor...');
        
        while (this.isRunning) {
            try {
                if (this.stopRequested) {
                    await this.sleep(300);
                    continue;
                }

                // Check if we can process more tasks
                if (this.processingCount >= this.maxConcurrent) {
                    await this.sleep(1000);
                    continue;
                }

                // Get task from queue (blocking with timeout)
                const taskData = await this.redis.blPop(this.config.redisQueue, 5);
                
                if (taskData && taskData.element) {
                    try {
                        // Validate and parse JSON data
                        const rawElement = typeof taskData.element === 'string'
                            ? taskData.element
                            : taskData.element.toString('utf8');
                        const trimmedElement = rawElement.trim();

                        if (!trimmedElement) {
                            console.warn('Received empty or invalid task data, skipping...');
                            continue;
                        }
                        
                        const task = JSON.parse(trimmedElement);
                        if (task && task.target_domain && !task.targetDomain) {
                            task.targetDomain = task.target_domain;
                        }
                        
                        // Validate required task fields
                        if (!task || !task.url || !task.anchor || !task.targetDomain) {
                            console.warn('Invalid task structure, missing required fields:', task);
                            continue;
                        }

                        if (this.stopRequested) {
                            console.log(`Stop requested, skipping task: ${task.url}`);
                            continue;
                        }
                        
                        this.processingCount++;
                        console.log(`Processing task: ${task.url} (concurrent: ${this.processingCount})`);
                        
                        // Process task asynchronously
                        this.processTask(task).catch(error => {
                            console.error(`Error processing task ${task.url}:`, error);
                        }).finally(() => {
                            this.processingCount--;
                        });
                    } catch (parseError) {
                        console.error('JSON parse error:', parseError.message);
                        console.error('Raw data received:', taskData.element);
                        // Move invalid data to error queue for debugging
                        try {
                            await this.redis.lPush(this.config.redisErrorQueue, taskData.element);
                        } catch (redisError) {
                            console.error('Failed to move invalid data to error queue:', redisError.message);
                        }
                    }
                }
            } catch (error) {
                console.error('Queue processor error:', error);
                await this.sleep(5000); // Wait before retrying
            }
        }
    }

    async processTask(task) {
        const startTime = Date.now();
        let shouldSendResult = true;
        let page = null;
        let result = {
            url: task.url,
            anchor: task.anchor,
            target_domain: task.targetDomain,
            targetDomain: task.targetDomain,
            status: 'failed',
            responseTime: 0,
            error: null,
            timestamp: new Date().toISOString()
        };

        try {
            this.ensureActive();
            console.log(`Starting browser automation for: ${task.url}`);
            
            page = await this.browser.newPage();
            this.activePages.add(page);
            
            // Set random user agent
            const userAgent = new UserAgent();
            const uaString = userAgent.toString();
            if (typeof page.setUserAgent === 'function') {
                await page.setUserAgent(uaString);
            } else {
                await page.setExtraHTTPHeaders({ 'User-Agent': uaString });
                console.log('[ua] set via extra headers');
            }
            
            // Set viewport
            await page.setViewportSize({ width: 1366, height: 768 });
            
            // Navigate to URL
            this.ensureActive();
            console.log(`[nav] goto ${task.url}`);
            await this.gotoWithRetry(page, task.url, 2);
            console.log(`[nav] loaded ${task.url}`);
            
            // Wait for page to load
            this.ensureActive();
            await page.waitForTimeout(2000);
            
            // Try to find and fill forms or inject backlink
            const injectionResult = await this.injectBacklink(page, task);
            
            if (injectionResult.ok) {
                this.ensureActive();
                await page.waitForTimeout(10000);
                const verify = await this.verifySubmission(page, task);
                if (verify.ok) {
                    result.status = 'success';
                    if (verify.note) {
                        result.error = verify.note;
                    }
                    console.log(`Submission verified: ${task.url}`);
                } else {
                    result.status = 'failed';
                    result.error = verify.reason || 'Post-submit verification failed';
                    console.warn(`Verification failed for ${task.url}: ${result.error}`);
                }
            } else {
                result.status = 'failed';
                result.error = injectionResult.reason || 'No suitable injection point found';
                console.warn(`Injection failed for ${task.url}: ${result.error}`);
            }
            
        } catch (error) {
            const msg = error && error.message ? error.message : String(error);
            if (msg === 'PROCESS_STOPPED') {
                shouldSendResult = false;
                console.log(`Task aborted by stop signal: ${task.url}`);
            }
            if (
                msg.includes('net::ERR_HTTP_RESPONSE_CODE_FAILURE') ||
                msg.includes('net::ERR_CERT_AUTHORITY_INVALID') ||
                (msg.includes('page.goto') && msg.includes('Timeout 60000ms exceeded'))
            ) {
                result.error = 'This LINK ALREADY DEATH bruh';
            } else {
                result.error = msg;
            }
            console.error(`Failed to process ${task.url}:`, msg);
        } finally {
            if (page) {
                try {
                    if (!page.isClosed()) {
                        await page.close();
                    }
                } catch (closeError) {
                    console.warn(`Failed to close page for ${task.url}:`, closeError.message);
                } finally {
                    this.activePages.delete(page);
                }
            }
        }
        
        result.responseTime = Date.now() - startTime;
        
        // Send result back to Go orchestrator
        if (shouldSendResult) {
            await this.sendResult(result);
        }
        
        console.log(`Task completed: ${task.url} - ${result.status} (${result.responseTime}ms)`);
    }

    async injectBacklink(page, task) {
        try {
            this.ensureActive();
            // Try multiple injection strategies
            const attempts = [];
            await this.scrollForLazyLoad(page, attempts);
            await this.dismissPopups(page, attempts);
            await this.tryOpenReviewsTab(page, attempts);
            
            // Strategy 1: Look for comment forms
            const commentSelectors = [
                'textarea[name="comment"]',
                'textarea[name="message"]',
                'textarea[name="content"]',
                'textarea[id="comment"]',
                'textarea[id="message"]'
            ];
            
            for (const selector of commentSelectors) {
                this.ensureActive();
                try {
                    await page.waitForSelector(selector, { timeout: 5000 });
                    attempts.push(`comment:${selector}:found`);
                    
                    // Create backlink content
                    const backlinkContent = `<a href="${task.targetDomain}">${task.anchor}</a> Great content!`;
                    
                    await page.fill(selector, backlinkContent);
                    attempts.push(`comment:${selector}:filled`);

                    // Fill required author/email if present
                    await this.fillRequiredFields(page, attempts, task);
                    
                    // Look for submit button
                    const submitSelectors = [
                        'input[type="submit"]',
                        'button[type="submit"]',
                        'input[name="submit"]',
                        'button[name="submit"]'
                    ];
                    
                    for (const submitSelector of submitSelectors) {
                        this.ensureActive();
                        try {
                            await page.click(submitSelector);
                            await page.waitForTimeout(3000);
                            attempts.push(`comment:${selector}:submitted:${submitSelector}`);
                            return { ok: true };
                        } catch (e) {
                            attempts.push(`comment:${selector}:submit-failed:${submitSelector}:${e.message}`);
                            continue;
                        }
                    }
                } catch (e) {
                    attempts.push(`comment:${selector}:not-found:${e.message}`);
                    continue;
                }
            }
            
            // Strategy 2: Look for contact forms
            const contactSelectors = [
                'textarea[name="message"]',
                'textarea[name="inquiry"]',
                'textarea[id="message"]'
            ];
            
            for (const selector of contactSelectors) {
                this.ensureActive();
                try {
                    await page.waitForSelector(selector, { timeout: 5000 });
                    attempts.push(`contact:${selector}:found`);
                    
                    const message = `Hi, I wanted to share this useful resource: <a href="${task.targetDomain}">${task.anchor}</a>`;
                    
                    await page.fill(selector, message);
                    attempts.push(`contact:${selector}:filled`);
                    
                    const submitBtn = await page.$('input[type="submit"], button[type="submit"]');
                    if (submitBtn) {
                        await submitBtn.click();
                        await page.waitForTimeout(3000);
                        attempts.push(`contact:${selector}:submitted`);
                        return { ok: true };
                    }
                    attempts.push(`contact:${selector}:submit-not-found`);
                } catch (e) {
                    attempts.push(`contact:${selector}:not-found:${e.message}`);
                    continue;
                }
            }
            
            return { ok: false, reason: `no injection point; attempts=${attempts.join('|')}` };
            
        } catch (error) {
            console.error('Backlink injection error:', error);
            return { ok: false, reason: `injectBacklink error: ${error.message}` };
        }
    }

    async gotoWithRetry(page, url, attempts) {
        let lastError = null;
        for (let i = 1; i <= attempts; i++) {
            this.ensureActive();
            try {
                await page.goto(url, {
                    waitUntil: 'domcontentloaded',
                    timeout: 60000
                });
                return;
            } catch (error) {
                lastError = error;
                console.warn(`[nav] attempt ${i} failed: ${error.message}`);
                await this.sleep(2000);
            }
        }
        throw lastError;
    }

    async scrollForLazyLoad(page, attempts) {
        try {
            await page.evaluate(() => {
                window.scrollTo(0, document.body.scrollHeight);
            });
            await page.waitForTimeout(1500);
            await page.evaluate(() => {
                window.scrollTo(0, 0);
            });
            await page.waitForTimeout(500);
            attempts.push('scroll:ok');
        } catch (e) {
            attempts.push(`scroll:failed:${e.message}`);
        }
    }

    async verifySubmission(page, task) {
        try {
            this.ensureActive();
            await page.waitForTimeout(3000);

            const moderation = await page.evaluate(() => {
                const text = document.body ? document.body.innerText.toLowerCase() : '';
                const patterns = [
                    'awaiting moderation',
                    'pending moderation',
                    'your comment is awaiting moderation',
                    'comment awaiting moderation'
                ];
                return patterns.some(p => text.includes(p));
            });
            if (moderation) {
                return { ok: false, reason: 'comment awaiting moderation' };
            }

            const anchor = task.anchor;
            const target = task.targetDomain;

            const anchorLinkFound = await page.evaluate(({ anchor, target }) => {
                const links = Array.from(document.querySelectorAll('a'));
                return links.some(a => {
                    const href = a.getAttribute('href') || '';
                    const text = (a.textContent || '').trim();
                    return href.includes(target) && text.includes(anchor);
                });
            }, { anchor, target });

            if (anchorLinkFound) {
                return { ok: true };
            }

            const anchorTextFound = await page.evaluate(({ anchor }) => {
                const text = document.body ? document.body.innerText : '';
                return text.includes(anchor);
            }, { anchor });

            if (anchorTextFound) {
                return { ok: true, note: 'anchor text found without link (sanitized)' };
            }

            return { ok: false, reason: 'anchor text not found after submit' };
        } catch (error) {
            return { ok: false, reason: `verification error: ${error.message}` };
        }
    }

    async tryOpenReviewsTab(page, attempts) {
        const selectors = [
            '#tab-title-reviews a',
            'a[href="#tab-reviews"]',
            '#tab-title-reviews',
            '#reviews'
        ];

        for (const selector of selectors) {
            try {
                const el = await page.$(selector);
                if (el) {
                    await el.click({ timeout: 2000 });
                    await page.waitForTimeout(1000);
                    attempts.push(`reviews:clicked:${selector}`);
                    return;
                }
            } catch (e) {
                attempts.push(`reviews:click-failed:${selector}:${e.message}`);
            }
        }
    }

    async fillRequiredFields(page, attempts, task) {
        const dummyName = process.env.DUMMY_NAME || 'BackLynx Bot';
        const dummyEmail = process.env.DUMMY_EMAIL || 'backlynx@example.com';

        try {
            const authorInput = await page.$('input#author, input[name="author"]');
            if (authorInput) {
                await authorInput.fill(dummyName);
                attempts.push('field:author:filled');
            }
        } catch (e) {
            attempts.push(`field:author:failed:${e.message}`);
        }

        try {
            const emailInput = await page.$('input#email, input[name="email"]');
            if (emailInput) {
                await emailInput.fill(dummyEmail);
                attempts.push('field:email:filled');
            }
        } catch (e) {
            attempts.push(`field:email:failed:${e.message}`);
        }

        try {
            const urlInput = await page.$('input#url, input[name="url"]');
            if (urlInput && task && task.targetDomain) {
                await urlInput.fill(task.targetDomain);
                attempts.push('field:url:filled');
            }
        } catch (e) {
            attempts.push(`field:url:failed:${e.message}`);
        }
    }

    async dismissPopups(page, attempts) {
        const selectors = [
            'button:has-text("I am 21")',
            'button:has-text("I\'m 21")',
            'button:has-text("Yes")',
            'button:has-text("Enter")',
            'button:has-text("Accept")',
            'button:has-text("I agree")',
            'button:has-text("Agree")',
            'button:has-text("Got it")',
            'text=I am 21',
            'text=I\'m 21',
            'text=Accept',
            'text=I agree',
            'text=Agree',
            'text=Got it'
        ];

        for (const selector of selectors) {
            try {
                const el = await page.$(selector);
                if (el) {
                    await el.click({ timeout: 1500 });
                    await page.waitForTimeout(500);
                    attempts.push(`popup:clicked:${selector}`);
                    return;
                }
            } catch (e) {
                attempts.push(`popup:click-failed:${selector}:${e.message}`);
            }
        }
    }

    async sendResult(result) {
        try {
            if (this.redis) {
                await this.redis.lPush(this.config.redisResultQueue, JSON.stringify(result));
                return;
            }

            const response = await axios.post(
                `http://${this.config.goHost}:${this.config.goPort}/api/v1/result`,
                result,
                { timeout: 10000 }
            );
            return response.data;
        } catch (error) {
            console.error('Failed to send result:', error.message);
        }
    }

    async startHealthCheck() {
        setInterval(async () => {
            try {
                await this.redis.ping();
                console.log(`Health check passed - Processing: ${this.processingCount}/${this.maxConcurrent}`);
            } catch (error) {
                console.error('Health check failed:', error);
            }
        }, 30000);
    }

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    ensureActive() {
        if (this.stopRequested || !this.isRunning) {
            throw new Error('PROCESS_STOPPED');
        }
    }

    async handleControlMessage(message) {
        let payload = null;
        try {
            payload = JSON.parse(message);
        } catch (error) {
            payload = { action: String(message || '').trim() };
        }

        const action = (payload.action || '').toLowerCase();
        if (action === 'stop') {
            this.stopRequested = true;
            console.log('Received STOP control signal');
            await this.abortActivePages();
            return;
        }
        if (action === 'start') {
            this.stopRequested = false;
            console.log('Received START control signal');
        }
    }

    async abortActivePages() {
        const pages = Array.from(this.activePages);
        for (const page of pages) {
            try {
                if (!page.isClosed()) {
                    await page.close();
                }
            } catch (error) {
                console.warn('Failed to close active page:', error.message);
            } finally {
                this.activePages.delete(page);
            }
        }
    }

    async stop() {
        this.isRunning = false;
        this.stopRequested = true;
        await this.abortActivePages();
        
        if (this.browser) {
            await this.browser.close();
        }

        if (this.control) {
            await this.control.disconnect();
        }
        
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
