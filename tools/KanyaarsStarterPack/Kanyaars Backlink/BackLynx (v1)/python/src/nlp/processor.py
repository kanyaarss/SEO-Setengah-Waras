import asyncio
import logging
import re
from typing import Dict, List, Optional, Tuple
from collections import Counter
import nltk
from nltk.sentiment import SentimentIntensityAnalyzer
from nltk.tokenize import word_tokenize, sent_tokenize
from nltk.corpus import stopwords
from langdetect import detect
from textblob import TextBlob

logger = logging.getLogger(__name__)

class NLPProcessor:
    def __init__(self):
        self.sia = None
        self.stop_words = set()
        self.processed_count = 0
        self._initialized = False

    async def initialize(self):
        """Initialize NLP components"""
        try:
            # Download required NLTK data
            try:
                nltk.data.find('tokenizers/punkt')
            except LookupError:
                nltk.download('punkt', quiet=True)
            
            try:
                nltk.data.find('corpora/stopwords')
            except LookupError:
                nltk.download('stopwords', quiet=True)
            
            try:
                nltk.data.find('sentiment/vader_lexicon')
            except LookupError:
                nltk.download('vader_lexicon', quiet=True)

            # Initialize components
            self.sia = SentimentIntensityAnalyzer()
            self.stop_words = set(stopwords.words('english'))
            self._initialized = True
            
            logger.info("NLP processor initialized successfully")

        except Exception as e:
            logger.error(f"Failed to initialize NLP processor: {e}")
            raise

    async def analyze(self, text: str) -> Dict:
        """Perform comprehensive NLP analysis"""
        if not self._initialized:
            await self.initialize()

        self.processed_count += 1

        try:
            analysis = {
                "language": self._detect_language(text),
                "sentiment": self._analyze_sentiment(text),
                "readability": self._analyze_readability(text),
                "keywords": self._extract_keywords(text),
                "entities": self._extract_entities(text),
                "statistics": self._get_text_statistics(text),
                "quality_metrics": self._assess_text_quality(text)
            }

            return analysis

        except Exception as e:
            logger.error(f"NLP analysis failed: {e}")
            return {
                "error": str(e),
                "language": "unknown",
                "sentiment": "neutral",
                "readability": 0.0,
                "keywords": [],
                "entities": [],
                "statistics": {},
                "quality_metrics": {}
            }

    def _detect_language(self, text: str) -> str:
        """Detect language of text"""
        try:
            if len(text.strip()) < 10:
                return "unknown"
            
            # Use langdetect for primary detection
            lang = detect(text)
            return lang if lang in ['en', 'es', 'fr', 'de', 'it', 'pt'] else 'unknown'

        except Exception as e:
            logger.warning(f"Language detection failed: {e}")
            return "unknown"

    def _analyze_sentiment(self, text: str) -> Dict:
        """Analyze sentiment using multiple methods"""
        try:
            # VADER sentiment
            vader_scores = self.sia.polarity_scores(text)
            
            # TextBlob sentiment
            blob = TextBlob(text)
            textblob_polarity = blob.sentiment.polarity
            textblob_subjectivity = blob.sentiment.subjectivity

            # Combine results
            compound_score = vader_scores['compound']
            
            if compound_score >= 0.05:
                sentiment = "positive"
            elif compound_score <= -0.05:
                sentiment = "negative"
            else:
                sentiment = "neutral"

            return {
                "sentiment": sentiment,
                "vader": vader_scores,
                "textblob": {
                    "polarity": textblob_polarity,
                    "subjectivity": textblob_subjectivity
                },
                "confidence": abs(compound_score)
            }

        except Exception as e:
            logger.warning(f"Sentiment analysis failed: {e}")
            return {
                "sentiment": "neutral",
                "confidence": 0.0,
                "error": str(e)
            }

    def _analyze_readability(self, text: str) -> Dict:
        """Analyze text readability"""
        try:
            sentences = sent_tokenize(text)
            words = word_tokenize(text)
            
            if not sentences or not words:
                return {"score": 0.0, "level": "unknown"}

            # Basic metrics
            avg_sentence_length = len(words) / len(sentences)
            avg_word_length = sum(len(word) for word in words) / len(words)
            
            # Simple readability score (based on average sentence length)
            readability_score = max(0, min(100, 100 - (avg_sentence_length - 15) * 2))
            
            # Determine readability level
            if readability_score >= 80:
                level = "easy"
            elif readability_score >= 60:
                level = "moderate"
            elif readability_score >= 40:
                level = "difficult"
            else:
                level = "very_difficult"

            return {
                "score": readability_score,
                "level": level,
                "avg_sentence_length": avg_sentence_length,
                "avg_word_length": avg_word_length,
                "sentence_count": len(sentences),
                "word_count": len(words)
            }

        except Exception as e:
            logger.warning(f"Readability analysis failed: {e}")
            return {"score": 0.0, "level": "unknown"}

    def _extract_keywords(self, text: str, max_keywords: int = 10) -> List[Dict]:
        """Extract keywords from text"""
        try:
            # Tokenize and normalize
            words = word_tokenize(text.lower())
            
            # Remove stop words and punctuation
            filtered_words = [
                word for word in words 
                if word.isalpha() 
                and word not in self.stop_words 
                and len(word) > 2
            ]
            
            # Count word frequencies
            word_freq = Counter(filtered_words)
            
            # Get top keywords
            top_words = word_freq.most_common(max_keywords)
            
            keywords = []
            for word, freq in top_words:
                keywords.append({
                    "word": word,
                    "frequency": freq,
                    "relevance": freq / len(filtered_words)
                })

            return keywords

        except Exception as e:
            logger.warning(f"Keyword extraction failed: {e}")
            return []

    def _extract_entities(self, text: str) -> List[Dict]:
        """Extract named entities (simplified version)"""
        try:
            # Simple entity extraction using patterns
            entities = []
            
            # Email pattern
            email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
            emails = re.findall(email_pattern, text)
            for email in emails:
                entities.append({"type": "email", "value": email})
            
            # URL pattern
            url_pattern = r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+'
            urls = re.findall(url_pattern, text)
            for url in urls:
                entities.append({"type": "url", "value": url})
            
            # Domain pattern
            domain_pattern = r'\b(?:www\.)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'
            domains = re.findall(domain_pattern, text)
            for domain in domains:
                if domain not in [url for url in urls]:
                    entities.append({"type": "domain", "value": domain})
            
            return entities

        except Exception as e:
            logger.warning(f"Entity extraction failed: {e}")
            return []

    def _get_text_statistics(self, text: str) -> Dict:
        """Get basic text statistics"""
        try:
            sentences = sent_tokenize(text)
            words = word_tokenize(text)
            characters = len(text)
            characters_no_spaces = len(text.replace(" ", ""))
            
            return {
                "character_count": characters,
                "character_count_no_spaces": characters_no_spaces,
                "word_count": len(words),
                "sentence_count": len(sentences),
                "avg_words_per_sentence": len(words) / len(sentences) if sentences else 0,
                "avg_chars_per_word": characters / len(words) if words else 0
            }

        except Exception as e:
            logger.warning(f"Text statistics failed: {e}")
            return {}

    def _assess_text_quality(self, text: str) -> Dict:
        """Assess text quality metrics"""
        try:
            quality_score = 0.0
            issues = []
            
            # Length check
            if len(text.strip()) < 20:
                issues.append("too_short")
            elif len(text.strip()) > 500:
                issues.append("too_long")
            else:
                quality_score += 0.2
            
            # Vocabulary diversity
            words = word_tokenize(text.lower())
            unique_words = set(words)
            if len(words) > 0:
                diversity = len(unique_words) / len(words)
                if diversity > 0.6:
                    quality_score += 0.2
                elif diversity < 0.3:
                    issues.append("low_diversity")
            
            # Sentence structure
            sentences = sent_tokenize(text)
            if len(sentences) > 1:
                quality_score += 0.1
            
            # Grammar check (simplified)
            if text.strip().endswith(('.', '!', '?')):
                quality_score += 0.1
            
            # Capitalization
            if text[0].isupper():
                quality_score += 0.1
            
            # No excessive punctuation
            punctuation_count = sum(1 for char in text if char in '!?.,;:')
            if punctuation_count / len(text) < 0.1:
                quality_score += 0.1
            
            # No excessive repetition
            word_freq = Counter(words)
            most_common = word_freq.most_common(1)
            if most_common:
                most_freq_word, freq = most_common[0]
                if freq / len(words) < 0.2:
                    quality_score += 0.2
                else:
                    issues.append("excessive_repetition")

            return {
                "score": min(1.0, quality_score),
                "issues": issues,
                "grade": self._get_quality_grade(quality_score)
            }

        except Exception as e:
            logger.warning(f"Quality assessment failed: {e}")
            return {"score": 0.0, "issues": ["analysis_failed"], "grade": "F"}

    def _get_quality_grade(self, score: float) -> str:
        """Convert quality score to grade"""
        if score >= 0.9:
            return "A"
        elif score >= 0.8:
            return "B"
        elif score >= 0.7:
            return "C"
        elif score >= 0.6:
            return "D"
        else:
            return "F"

    async def get_processed_count(self) -> int:
        """Get total processed count"""
        return self.processed_count

    async def reset_count(self):
        """Reset processed count"""
        self.processed_count = 0
