const UserAgent = require('user-agents');

class StealthManager {
    constructor() {
        this.userAgents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/121.0'
        ];

        this.viewports = [
            { width: 1920, height: 1080 },
            { width: 1366, height: 768 },
            { width: 1440, height: 900 },
            { width: 1536, height: 864 },
            { width: 1280, height: 720 }
        ];

        this.timezones = [
            'America/New_York',
            'America/Los_Angeles',
            'Europe/London',
            'Europe/Paris',
            'Asia/Tokyo',
            'Australia/Sydney'
        ];

        this.languages = [
            ['en-US', 'en'],
            ['en-GB', 'en'],
            ['es-US', 'es'],
            ['fr-FR', 'fr'],
            ['de-DE', 'de']
        ];
    }

    async applyStealth(page) {
        try {
            // Set random user agent
            const userAgent = this.getRandomUserAgent();
            await page.setUserAgent(userAgent);

            // Set random viewport
            const viewport = this.getRandomViewport();
            await page.setViewport(viewport);

            // Set random timezone
            const timezone = this.getRandomTimezone();
            await page.emulateTimezone(timezone);

            // Set random language
            const language = this.getRandomLanguage();
            await page.setExtraHTTPHeaders({
                'Accept-Language': language.join(',')
            });

            // Override navigator properties
            await this.overrideNavigator(page);

            // Set random screen properties
            await this.setScreenProperties(page);

            // Disable webdriver flag
            await page.evaluateOnNewDocument(() => {
                Object.defineProperty(navigator, 'webdriver', {
                    get: () => undefined,
                });
            });

            // Override plugins
            await page.evaluateOnNewDocument(() => {
                Object.defineProperty(navigator, 'plugins', {
                    get: () => [
                        {
                            0: {
                                type: "application/x-google-chrome-pdf",
                                suffixes: "pdf",
                                description: "Portable Document Format",
                                enabledPlugin: Plugin
                            },
                            description: "Portable Document Format",
                            filename: "internal-pdf-viewer",
                            length: 1,
                            name: "Chrome PDF Plugin"
                        }
                    ],
                });
            });

            // Override permissions
            await page.evaluateOnNewDocument(() => {
                const originalQuery = window.navigator.permissions.query;
                window.navigator.permissions.query = (parameters) => (
                    parameters.name === 'notifications' ?
                        Promise.resolve({ state: Notification.permission }) :
                        originalQuery(parameters)
                );
            });

            // Add random mouse movement
            await this.simulateHumanBehavior(page);

            console.log('Stealth mode applied successfully');

        } catch (error) {
            console.error('Error applying stealth mode:', error);
        }
    }

    getRandomUserAgent() {
        return this.userAgents[Math.floor(Math.random() * this.userAgents.length)];
    }

    getRandomViewport() {
        return this.viewports[Math.floor(Math.random() * this.viewports.length)];
    }

    getRandomTimezone() {
        return this.timezones[Math.floor(Math.random() * this.timezones.length)];
    }

    getRandomLanguage() {
        return this.languages[Math.floor(Math.random() * this.languages.length)];
    }

    async overrideNavigator(page) {
        await page.evaluateOnNewDocument(() => {
            // Override navigator properties
            Object.defineProperty(navigator, 'hardwareConcurrency', {
                get: () => 4
            });

            Object.defineProperty(navigator, 'deviceMemory', {
                get: () => 8
            });

            Object.defineProperty(navigator, 'maxTouchPoints', {
                get: () => 0
            });

            Object.defineProperty(navigator, 'platform', {
                get: () => 'Win32'
            });

            // Random battery API
            Object.defineProperty(navigator, 'getBattery', {
                get: () => () => Promise.resolve({
                    charging: Math.random() > 0.5,
                    chargingTime: Math.random() * 3600,
                    dischargingTime: Math.random() * 7200,
                    level: Math.random() * 0.5 + 0.5
                })
            });

            // Override connection
            Object.defineProperty(navigator, 'connection', {
                get: () => ({
                    effectiveType: ['4g', '3g'][Math.floor(Math.random() * 2)],
                    rtt: Math.floor(Math.random() * 100) + 50,
                    downlink: Math.random() * 10 + 1
                })
            });
        });
    }

    async setScreenProperties(page) {
        await page.evaluateOnNewDocument(() => {
            // Random screen properties
            const screenWidth = 1920;
            const screenHeight = 1080;
            const availWidth = screenWidth - Math.floor(Math.random() * 100);
            const availHeight = screenHeight - Math.floor(Math.random() * 100);
            const colorDepth = 24;
            const pixelDepth = 24;

            Object.defineProperty(screen, 'width', {
                get: () => screenWidth
            });

            Object.defineProperty(screen, 'height', {
                get: () => screenHeight
            });

            Object.defineProperty(screen, 'availWidth', {
                get: () => availWidth
            });

            Object.defineProperty(screen, 'availHeight', {
                get: () => availHeight
            });

            Object.defineProperty(screen, 'colorDepth', {
                get: () => colorDepth
            });

            Object.defineProperty(screen, 'pixelDepth', {
                get: () => pixelDepth
            });
        });
    }

    async simulateHumanBehavior(page) {
        try {
            // Random mouse movements
            await page.evaluate(() => {
                const moveMouse = () => {
                    const x = Math.random() * window.innerWidth;
                    const y = Math.random() * window.innerHeight;
                    const event = new MouseEvent('mousemove', {
                        clientX: x,
                        clientY: y,
                        bubbles: true
                    });
                    document.dispatchEvent(event);
                };

                // Move mouse randomly every few seconds
                setInterval(moveMouse, Math.random() * 5000 + 2000);
            });

            // Random scroll behavior
            await page.evaluate(() => {
                const randomScroll = () => {
                    const scrollY = Math.random() * document.body.scrollHeight;
                    window.scrollTo({
                        top: scrollY,
                        behavior: 'smooth'
                    });
                };

                // Scroll randomly every 10-20 seconds
                setTimeout(() => {
                    setInterval(randomScroll, Math.random() * 10000 + 10000);
                }, Math.random() * 5000 + 2000);
            });

        } catch (error) {
            console.error('Error simulating human behavior:', error);
        }
    }

    async addRandomDelay(min = 1000, max = 3000) {
        const delay = Math.floor(Math.random() * (max - min + 1)) + min;
        await new Promise(resolve => setTimeout(resolve, delay));
    }

    async randomTyping(element, text, minDelay = 50, maxDelay = 150) {
        for (const char of text) {
            await element.type(char);
            const delay = Math.floor(Math.random() * (maxDelay - minDelay + 1)) + minDelay;
            await new Promise(resolve => setTimeout(resolve, delay));
        }
    }

    async randomMouseMovement(page) {
        try {
            const x = Math.random() * 1000;
            const y = Math.random() * 1000;
            await page.mouse.move(x, y);
            
            // Small delay between movements
            await this.addRandomDelay(100, 500);
        } catch (error) {
            console.error('Error during random mouse movement:', error);
        }
    }
}

module.exports = StealthManager;
