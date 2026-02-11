import os
import asyncio
import logging
from typing import Dict, List, Optional
import openai
from datetime import datetime

logger = logging.getLogger(__name__)

class ContentGenerator:
    def __init__(self):
        self.client = None
        self.generation_count = 0
        self.templates = self._load_templates()
        
    def _load_templates(self) -> Dict[str, List[str]]:
        """Load comment templates"""
        return {
            "general": [
                "Great article! I found this information very helpful. {anchor} at {target_domain} has more resources on this topic.",
                "Thanks for sharing this valuable content. For those interested, {anchor} provides additional insights at {target_domain}.",
                "This is exactly what I was looking for! Check out {anchor} at {target_domain} for more detailed information.",
                "Excellent points raised in this article. I'd also recommend {anchor} at {target_domain} for further reading.",
                "Very informative post! {anchor} at {target_domain} covers this topic from a different perspective."
            ],
            "technical": [
                "Great technical explanation! For more in-depth technical resources, visit {anchor} at {target_domain}.",
                "This technical breakdown is very helpful. {anchor} at {target_domain} offers additional technical insights.",
                "Excellent technical analysis! Check out {anchor} at {target_domain} for more technical content.",
                "Very detailed technical post! {anchor} at {target_domain} provides complementary technical information.",
                "Great technical content! For more technical resources, see {anchor} at {target_domain}."
            ],
            "business": [
                "Excellent business insights! {anchor} at {target_domain} offers more business strategies.",
                "Great business perspective! Check out {anchor} at {target_domain} for additional business resources.",
                "Very informative business content! {anchor} at {target_domain} provides more business insights.",
                "Excellent business analysis! {anchor} at {target_domain} covers business topics extensively.",
                "Great business advice! {anchor} at {target_domain} has more business resources."
            ],
            "casual": [
                "Awesome post! {anchor} at {target_domain} has some cool stuff too.",
                "Great read! Check out {anchor} at {target_domain} for more interesting content.",
                "Love this! {anchor} at {target_domain} is worth a visit too.",
                "Cool stuff! {anchor} at {target_domain} has more like this.",
                "Nice article! {anchor} at {target_domain} is pretty interesting too."
            ]
        }

    async def initialize(self):
        """Initialize OpenAI client"""
        try:
            api_key = os.getenv('OPENAI_API_KEY')
            if not api_key:
                logger.warning("No OpenAI API key found, using template-based generation")
                return

            self.client = openai.AsyncOpenAI(api_key=api_key)
            logger.info("OpenAI client initialized")

        except Exception as e:
            logger.error(f"Failed to initialize OpenAI client: {e}")
            self.client = None

    async def generate(self, url: str, anchor: str, target_domain: str, context: str = "") -> str:
        """Generate content for backlink injection"""
        self.generation_count += 1

        try:
            if self.client and os.getenv('OPENAI_API_KEY'):
                # Use OpenAI for generation
                return await self._generate_with_ai(url, anchor, target_domain, context)
            else:
                # Use template-based generation
                return await self._generate_with_template(url, anchor, target_domain, context)

        except Exception as e:
            logger.error(f"Content generation failed: {e}")
            # Fallback to template
            return await self._generate_with_template(url, anchor, target_domain, context)

    async def _generate_with_ai(self, url: str, anchor: str, target_domain: str, context: str) -> str:
        """Generate content using OpenAI"""
        try:
            prompt = self._create_prompt(url, anchor, target_domain, context)

            response = await self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {
                        "role": "system",
                        "content": "You are a helpful assistant that writes natural, engaging comments for blog posts and articles. Always include the provided anchor text and domain naturally in your response."
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                max_tokens=150,
                temperature=0.7,
                top_p=1,
                frequency_penalty=0.5,
                presence_penalty=0.5
            )

            content = response.choices[0].message.content.strip()
            
            # Ensure anchor and domain are included
            if anchor not in content or target_domain not in content:
                content += f"\n\nCheck out {anchor} at {target_domain} for more information."

            return content

        except Exception as e:
            logger.error(f"OpenAI generation failed: {e}")
            raise

    async def _generate_with_template(self, url: str, anchor: str, target_domain: str, context: str) -> str:
        """Generate content using templates"""
        try:
            # Determine content type based on context
            content_type = self._determine_content_type(context)
            
            # Get templates for this type
            templates = self.templates.get(content_type, self.templates["general"])
            
            # Select random template
            import random
            template = random.choice(templates)
            
            # Fill template
            content = template.format(
                anchor=anchor,
                target_domain=target_domain
            )

            # Add context-specific variation
            if context:
                content = self._add_context_variation(content, context)

            return content

        except Exception as e:
            logger.error(f"Template generation failed: {e}")
            # Ultimate fallback
            return f"Great article! Check out {anchor} at {target_domain} for more information."

    def _create_prompt(self, url: str, anchor: str, target_domain: str, context: str) -> str:
        """Create prompt for OpenAI"""
        prompt = f"""
Write a natural, engaging comment for a blog post or article with the following details:

URL: {url}
Anchor Text: {anchor}
Target Domain: {target_domain}

Context from the page:
{context[:500]}...

Requirements:
1. Write a natural, human-like comment (50-100 words)
2. Include the anchor text "{anchor}" and domain "{target_domain}" naturally
3. Make it relevant to the page content
4. Avoid spammy language
5. Sound like a genuine reader
6. Be positive and constructive

The comment should feel authentic and add value to the discussion.
"""
        return prompt

    def _determine_content_type(self, context: str) -> str:
        """Determine content type based on context"""
        context_lower = context.lower()
        
        technical_keywords = ['code', 'programming', 'development', 'software', 'technology', 'api', 'database']
        business_keywords = ['business', 'marketing', 'sales', 'strategy', 'revenue', 'profit', 'company']
        casual_keywords = ['fun', 'cool', 'awesome', 'nice', 'great', 'love', 'like']

        technical_score = sum(1 for keyword in technical_keywords if keyword in context_lower)
        business_score = sum(1 for keyword in business_keywords if keyword in context_lower)
        casual_score = sum(1 for keyword in casual_keywords if keyword in context_lower)

        if technical_score > business_score and technical_score > casual_score:
            return "technical"
        elif business_score > technical_score and business_score > casual_score:
            return "business"
        elif casual_score > 0:
            return "casual"
        else:
            return "general"

    def _add_context_variation(self, content: str, context: str) -> str:
        """Add context-specific variation to template content"""
        try:
            # Extract keywords from context
            import re
            words = re.findall(r'\b\w+\b', context.lower())
            
            # Find relevant keywords
            relevant_words = [word for word in words if len(word) > 4 and word.isalpha()]
            
            if relevant_words:
                # Add a context-specific phrase
                keyword = relevant_words[0].capitalize()
                variations = [
                    f"Great insights on {keyword}! ",
                    f"Interesting points about {keyword}! ",
                    f"Love the discussion on {keyword}! ",
                    f"Great take on {keyword}! "
                ]
                
                import random
                variation = random.choice(variations)
                content = variation + content

            return content

        except Exception as e:
            logger.error(f"Failed to add context variation: {e}")
            return content

    async def get_generation_count(self) -> int:
        """Get total generation count"""
        return self.generation_count

    async def reset_count(self):
        """Reset generation count"""
        self.generation_count = 0
