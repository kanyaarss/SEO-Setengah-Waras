const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const RecaptchaPlugin = require('puppeteer-extra-plugin-recaptcha');
const UserAgent = require('user-agents');

puppeteer.use(StealthPlugin());
puppeteer.use(RecaptchaPlugin({
    provider: { id: '2captcha', token: process.env.RECAPTCHA_TOKEN },
    visualFeedback: true
}));

class BrowserWorker {
    constructor(config) {
        this.config = config;
        this.browser = null;
        this.pages = new Map();
        this.pageCounter = 0;
    }

    async initialize() {
        try {
            const browserOptions = {
                headless: this.config.headless,
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-accelerated-2d-canvas',
                    '--no-first-run',
                    '--no-zygote',
                    '--disable-gpu',
                    '--disable-background-timer-throttling',
                    '--disable-backgrounding-occluded-windows',
                    '--disable-renderer-backgrounding',
                    '--disable-features=TranslateUI',
                    '--disable-ipc-flooding-protection',
                    '--window-size=1920,1080'
                ],
                defaultViewport: {
                    width: 1920,
                    height: 1080
                }
            };

            this.browser = await puppeteer.launch(browserOptions);
            console.log('Browser initialized successfully');

        } catch (error) {
            console.error('Failed to initialize browser:', error);
            throw error;
        }
    }

    async getNewPage() {
        if (!this.browser) {
            throw new Error('Browser not initialized');
        }

        const pageId = ++this.pageCounter;
        const page = await this.browser.newPage();

        // Set random user agent
        const userAgent = new UserAgent();
        await page.setUserAgent(userAgent.toString());

        // Set additional headers
        await page.setExtraHTTPHeaders({
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1'
        });

        // Handle JavaScript errors
        page.on('pageerror', (error) => {
            console.error(`Page ${pageId} JavaScript error:`, error.message);
        });

        // Handle console messages
        page.on('console', (msg) => {
            if (msg.type() === 'error') {
                console.error(`Page ${pageId} console error:`, msg.text());
            }
        });

        // Store page reference
        this.pages.set(pageId, page);

        // Cleanup on page close
        page.on('close', () => {
            this.pages.delete(pageId);
        });

        return page;
    }

    async closePage(page) {
        try {
            await page.close();
        } catch (error) {
            console.error('Error closing page:', error);
        }
    }

    async shutdown() {
        console.log('Closing all pages...');
        
        for (const [pageId, page] of this.pages) {
            try {
                await page.close();
            } catch (error) {
                console.error(`Error closing page ${pageId}:`, error);
            }
        }

        this.pages.clear();

        if (this.browser) {
            console.log('Closing browser...');
            await this.browser.close();
            this.browser = null;
        }
    }

    getBrowserInfo() {
        return {
            pagesCount: this.pages.size,
            isBrowserConnected: this.browser ? this.browser.isConnected() : false
        };
    }
}

module.exports = BrowserWorker;
