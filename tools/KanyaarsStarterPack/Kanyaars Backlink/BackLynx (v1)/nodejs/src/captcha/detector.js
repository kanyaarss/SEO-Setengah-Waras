class CaptchaDetector {
    constructor() {
        this.captchaSelectors = [
            // Google reCAPTCHA
            'div.g-recaptcha',
            'iframe[src*="recaptcha"]',
            'div[class*="recaptcha"]',
            
            // hCaptcha
            'iframe[src*="hcaptcha"]',
            'div[class*="hcaptcha"]',
            
            // Other common CAPTCHA indicators
            'img[src*="captcha"]',
            'img[alt*="captcha"]',
            'div[id*="captcha"]',
            'div[class*="captcha"]',
            
            // Text-based CAPTCHA
            'input[name*="captcha"]',
            'input[id*="captcha"]',
            'label[for*="captcha"]',
            
            // Math CAPTCHA
            '[class*="math"]',
            '[id*="math"]',
            
            // Audio CAPTCHA
            'audio[src*="captcha"]',
            
            // Cloudflare
            'div[class*="cf-turnstile"]',
            'iframe[src*="turnstile"]'
        ];

        this.captchaTextPatterns = [
            /captcha/i,
            /robot/i,
            /human/i,
            /verify.*human/i,
            /prove.*human/i,
            /security.*check/i,
            /anti.*bot/i,
            /i.*not.*robot/i
        ];
    }

    async detect(page) {
        try {
            // Check for CAPTCHA elements
            const hasCaptchaElements = await this.checkCaptchaElements(page);
            if (hasCaptchaElements) {
                console.log('CAPTCHA elements detected');
                return true;
            }

            // Check for CAPTCHA text
            const hasCaptchaText = await this.checkCaptchaText(page);
            if (hasCaptchaText) {
                console.log('CAPTCHA text detected');
                return true;
            }

            // Check for CAPTCHA challenges
            const hasCaptchaChallenge = await this.checkCaptchaChallenge(page);
            if (hasCaptchaChallenge) {
                console.log('CAPTCHA challenge detected');
                return true;
            }

            // Check for Cloudflare protection
            const hasCloudflare = await this.checkCloudflare(page);
            if (hasCloudflare) {
                console.log('Cloudflare protection detected');
                return true;
            }

            return false;

        } catch (error) {
            console.error('Error detecting CAPTCHA:', error);
            return false;
        }
    }

    async checkCaptchaElements(page) {
        for (const selector of this.captchaSelectors) {
            try {
                const elements = await page.$$(selector);
                for (const element of elements) {
                    const isVisible = await element.isVisible();
                    if (isVisible) {
                        console.log(`CAPTCHA element found: ${selector}`);
                        return true;
                    }
                }
            } catch (error) {
                // Continue checking other selectors
            }
        }
        return false;
    }

    async checkCaptchaText(page) {
        try {
            const pageText = await page.evaluate(() => {
                return document.body.innerText;
            });

            for (const pattern of this.captchaTextPatterns) {
                if (pattern.test(pageText)) {
                    console.log(`CAPTCHA text pattern matched: ${pattern}`);
                    return true;
                }
            }

            return false;

        } catch (error) {
            console.error('Error checking CAPTCHA text:', error);
            return false;
        }
    }

    async checkCaptchaChallenge(page) {
        try {
            // Check for common challenge indicators
            const challengeIndicators = [
                'input[placeholder*="captcha"]',
                'input[name*="captcha"]',
                'img[alt*="verification"]',
                'div[style*="background"][style*="image"]',
                'canvas[width][height]'
            ];

            for (const selector of challengeIndicators) {
                try {
                    const elements = await page.$$(selector);
                    for (const element of elements) {
                        const isVisible = await element.isVisible();
                        if (isVisible) {
                            console.log(`CAPTCHA challenge indicator found: ${selector}`);
                            return true;
                        }
                    }
                } catch (error) {
                    // Continue checking
                }
            }

            return false;

        } catch (error) {
            console.error('Error checking CAPTCHA challenge:', error);
            return false;
        }
    }

    async checkCloudflare(page) {
        try {
            const cloudflareSelectors = [
                'div.cf-browser-verification',
                'div.cf-im-under-attack',
                'div[class*="cf-"]',
                'form[action*="cf-challenge"]',
                'script[src*="cloudflare"]'
            ];

            for (const selector of cloudflareSelectors) {
                try {
                    const elements = await page.$$(selector);
                    for (const element of elements) {
                        const isVisible = await element.isVisible();
                        if (isVisible) {
                            console.log(`Cloudflare element found: ${selector}`);
                            return true;
                        }
                    }
                } catch (error) {
                    // Continue checking
                }
            }

            // Check for Cloudflare in page title
            const title = await page.title();
            if (title.toLowerCase().includes('cloudflare') || 
                title.toLowerCase().includes('just a moment')) {
                console.log('Cloudflare detected in page title');
                return true;
            }

            return false;

        } catch (error) {
            console.error('Error checking Cloudflare:', error);
            return false;
        }
    }

    async getCaptchaType(page) {
        try {
            // Check for reCAPTCHA
            const recaptcha = await page.$('div.g-recaptcha, iframe[src*="recaptcha"]');
            if (recaptcha) {
                return 'recaptcha';
            }

            // Check for hCaptcha
            const hcaptcha = await page.$('iframe[src*="hcaptcha"], div[class*="hcaptcha"]');
            if (hcaptcha) {
                return 'hcaptcha';
            }

            // Check for Cloudflare Turnstile
            const turnstile = await page.$('div[class*="cf-turnstile"], iframe[src*="turnstile"]');
            if (turnstile) {
                return 'turnstile';
            }

            // Check for text-based CAPTCHA
            const textCaptcha = await page.$('img[src*="captcha"], input[name*="captcha"]');
            if (textCaptcha) {
                return 'text';
            }

            return 'unknown';

        } catch (error) {
            console.error('Error getting CAPTCHA type:', error);
            return 'unknown';
        }
    }

    async waitForCaptchaToLoad(page, timeout = 5000) {
        try {
            await page.waitForTimeout(timeout);
            
            // Check if CAPTCHA is fully loaded
            const captchaLoaded = await page.evaluate(() => {
                const recaptcha = document.querySelector('.g-recaptcha');
                if (recaptcha && recaptcha.innerHTML.trim() === '') {
                    return false;
                }
                return true;
            });

            return captchaLoaded;

        } catch (error) {
            console.error('Error waiting for CAPTCHA to load:', error);
            return false;
        }
    }
}

module.exports = CaptchaDetector;
