class FormHandler {
    constructor() {
        this.formSelectors = [
            'form',
            'form[method="post"]',
            'form[action*="comment"]',
            'form[action*="submit"]',
            'form[class*="comment"]',
            'form[id*="comment"]'
        ];

        this.inputSelectors = {
            name: [
                'input[name="name"]',
                'input[name="author"]',
                'input[name="user"]',
                'input[name="username"]',
                'input[type="text"]',
                'input[placeholder*="name"]'
            ],
            email: [
                'input[name="email"]',
                'input[type="email"]',
                'input[placeholder*="email"]'
            ],
            website: [
                'input[name="website"]',
                'input[name="url"]',
                'input[name="site"]',
                'input[type="url"]'
            ],
            comment: [
                'textarea[name="comment"]',
                'textarea[name="message"]',
                'textarea[name="content"]',
                'textarea[name="text"]',
                'textarea[placeholder*="comment"]',
                'textarea[placeholder*="message"]'
            ],
            submit: [
                'input[type="submit"]',
                'button[type="submit"]',
                'button:contains("Submit")',
                'button:contains("Post")',
                'button:contains("Send")',
                'button:contains("Comment")'
            ]
        };
    }

    async findForms(page) {
        const forms = [];
        
        for (const selector of this.formSelectors) {
            try {
                const formElements = await page.$$(selector);
                for (const form of formElements) {
                    const isVisible = await form.isVisible();
                    if (isVisible) {
                        forms.push(form);
                    }
                }
            } catch (error) {
                // Continue to next selector
            }
        }

        return forms;
    }

    async findInput(page, type) {
        const selectors = this.inputSelectors[type] || [];
        
        for (const selector of selectors) {
            try {
                const element = await page.$(selector);
                if (element) {
                    const isVisible = await element.isVisible();
                    const isEnabled = await element.isEnabled();
                    if (isVisible && isEnabled) {
                        return element;
                    }
                }
            } catch (error) {
                // Continue to next selector
            }
        }

        return null;
    }

    async submitForm(page, form, data) {
        try {
            // Fill form fields
            await this.fillFormFields(page, form, data);

            // Handle potential anti-bot measures
            await this.handleAntiBot(page);

            // Submit form
            const submitted = await this.performSubmission(page, form);

            return submitted;

        } catch (error) {
            console.error('Form submission error:', error);
            return false;
        }
    }

    async fillFormFields(page, form, data) {
        // Fill name field
        const nameInput = await this.findInput(page, 'name');
        if (nameInput) {
            const randomName = this.generateRandomName();
            await nameInput.type(randomName, { delay: 100 });
        }

        // Fill email field
        const emailInput = await this.findInput(page, 'email');
        if (emailInput) {
            const randomEmail = this.generateRandomEmail();
            await emailInput.type(randomEmail, { delay: 100 });
        }

        // Fill website field with target domain
        const websiteInput = await this.findInput(page, 'website');
        if (websiteInput) {
            await websiteInput.type(`https://${data.targetDomain}`, { delay: 100 });
        }

        // Fill comment field with generated content
        const commentInput = await this.findInput(page, 'comment');
        if (commentInput) {
            // Add anchor text to comment
            const commentWithLink = `${data.content}\n\nCheck out ${data.anchor} at ${data.targetDomain}`;
            await commentInput.type(commentWithLink, { delay: 50 });
        }
    }

    async handleAntiBot(page) {
        try {
            // Wait a bit to simulate human behavior
            await page.waitForTimeout(this.randomDelay(1000, 3000));

            // Move mouse randomly
            await page.mouse.move(
                Math.random() * 1000,
                Math.random() * 1000
            );

            // Scroll a bit
            await page.evaluate(() => {
                window.scrollBy(0, Math.random() * 200);
            });

            await page.waitForTimeout(this.randomDelay(500, 1500));

        } catch (error) {
            // Continue even if anti-bot simulation fails
        }
    }

    async performSubmission(page, form) {
        try {
            // Find submit button
            const submitButton = await this.findInput(page, 'submit');
            
            if (submitButton) {
                // Click submit button
                await submitButton.click();
                
                // Wait for navigation or response
                await page.waitForNavigation({ 
                    waitUntil: 'networkidle2',
                    timeout: 10000 
                }).catch(() => {
                    // Navigation might not happen, continue
                });

                // Wait a bit to see if submission was successful
                await page.waitForTimeout(2000);

                // Check for success indicators
                const success = await this.checkSubmissionSuccess(page);
                return success;

            } else {
                // Try form.submit() as fallback
                await page.evaluate((form) => form.submit(), form);
                
                await page.waitForNavigation({ 
                    waitUntil: 'networkidle2',
                    timeout: 10000 
                }).catch(() => {
                    // Navigation might not happen, continue
                });

                await page.waitForTimeout(2000);
                return await this.checkSubmissionSuccess(page);
            }

        } catch (error) {
            console.error('Submission error:', error);
            return false;
        }
    }

    async checkSubmissionSuccess(page) {
        const successIndicators = [
            'thank you',
            'comment posted',
            'submission successful',
            'your comment has been',
            'successfully submitted',
            'comment submitted'
        ];

        const errorIndicators = [
            'error',
            'failed',
            'invalid',
            'incorrect',
            'please try again',
            'spam',
            'blocked'
        ];

        try {
            const pageText = await page.evaluate(() => document.body.innerText.toLowerCase());
            
            // Check for success indicators
            for (const indicator of successIndicators) {
                if (pageText.includes(indicator)) {
                    return true;
                }
            }

            // Check for error indicators
            for (const indicator of errorIndicators) {
                if (pageText.includes(indicator)) {
                    return false;
                }
            }

            // If no clear indicators, assume success (optimistic approach)
            return true;

        } catch (error) {
            console.error('Error checking submission success:', error);
            return false;
        }
    }

    generateRandomName() {
        const firstNames = ['John', 'Jane', 'Mike', 'Sarah', 'David', 'Emily', 'Chris', 'Lisa', 'Tom', 'Anna'];
        const lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez'];
        
        const firstName = firstNames[Math.floor(Math.random() * firstNames.length)];
        const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];
        
        return `${firstName} ${lastName}`;
    }

    generateRandomEmail() {
        const domains = ['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'example.com'];
        const names = ['user', 'person', 'individual', 'visitor', 'commenter'];
        
        const name = names[Math.floor(Math.random() * names.length)];
        const number = Math.floor(Math.random() * 9999);
        const domain = domains[Math.floor(Math.random() * domains.length)];
        
        return `${name}${number}@${domain}`;
    }

    randomDelay(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }
}

module.exports = FormHandler;
