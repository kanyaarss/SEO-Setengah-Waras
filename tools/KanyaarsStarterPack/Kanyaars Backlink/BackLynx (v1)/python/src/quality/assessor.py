import asyncio
import logging
import re
from typing import Dict, List, Optional, Tuple
from collections import Counter
from urllib.parse import urlparse

logger = logging.getLogger(__name__)

class QualityAssessor:
    def __init__(self):
        self.assessment_count = 0
        self.quality_thresholds = {
            "excellent": 0.9,
            "good": 0.7,
            "acceptable": 0.5,
            "poor": 0.3
        }

    async def initialize(self):
        """Initialize quality assessor"""
        try:
            logger.info("Quality assessor initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize quality assessor: {e}")
            raise

    async def assess_quality(self, content: str) -> float:
        """Assess overall content quality (0.0 - 1.0)"""
        self.assessment_count += 1

        try:
            quality_score = 0.0
            
            # Length appropriateness (20%)
            length_score = self._assess_length(content)
            quality_score += length_score * 0.2
            
            # Grammar and spelling (20%)
            grammar_score = self._assess_grammar(content)
            quality_score += grammar_score * 0.2
            
            # Readability (20%)
            readability_score = self._assess_readability(content)
            quality_score += readability_score * 0.2
            
            # Naturalness (20%)
            naturalness_score = self._assess_naturalness(content)
            quality_score += naturalness_score * 0.2
            
            # Relevance and coherence (20%)
            coherence_score = self._assess_coherence(content)
            quality_score += coherence_score * 0.2

            return min(1.0, quality_score)

        except Exception as e:
            logger.error(f"Quality assessment failed: {e}")
            return 0.0

    async def assess_relevance(self, content: str, context: str = "") -> float:
        """Assess content relevance to context (0.0 - 1.0)"""
        try:
            if not context:
                return 0.5  # Neutral score if no context

            relevance_score = 0.0
            
            # Keyword overlap (40%)
            keyword_score = self._assess_keyword_overlap(content, context)
            relevance_score += keyword_score * 0.4
            
            # Topic relevance (30%)
            topic_score = self._assess_topic_relevance(content, context)
            relevance_score += topic_score * 0.3
            
            # Semantic similarity (30%)
            semantic_score = self._assess_semantic_similarity(content, context)
            relevance_score += semantic_score * 0.3

            return min(1.0, relevance_score)

        except Exception as e:
            logger.error(f"Relevance assessment failed: {e}")
            return 0.0

    async def assess_seo(self, content: str, anchor: str, target_domain: str) -> float:
        """Assess SEO optimization (0.0 - 1.0)"""
        try:
            seo_score = 0.0
            
            # Anchor text inclusion (30%)
            anchor_score = self._assess_anchor_inclusion(content, anchor)
            seo_score += anchor_score * 0.3
            
            # Domain inclusion (30%)
            domain_score = self._assess_domain_inclusion(content, target_domain)
            seo_score += domain_score * 0.3
            
            # Natural placement (20%)
            placement_score = self._assess_natural_placement(content, anchor, target_domain)
            seo_score += placement_score * 0.2
            
            # Link context (20%)
            context_score = self._assess_link_context(content)
            seo_score += context_score * 0.2

            return min(1.0, seo_score)

        except Exception as e:
            logger.error(f"SEO assessment failed: {e}")
            return 0.0

    def _assess_length(self, content: str) -> float:
        """Assess content length appropriateness"""
        try:
            length = len(content.strip())
            
            if length < 20:
                return 0.2  # Too short
            elif length < 50:
                return 0.6  # Short but acceptable
            elif length <= 200:
                return 1.0  # Ideal length
            elif length <= 400:
                return 0.8  # Good length
            elif length <= 600:
                return 0.6  # Getting long
            else:
                return 0.3  # Too long

        except Exception as e:
            logger.warning(f"Length assessment failed: {e}")
            return 0.0

    def _assess_grammar(self, content: str) -> float:
        """Assess basic grammar quality"""
        try:
            grammar_score = 1.0
            
            # Check for basic grammar issues
            issues = []
            
            # Capitalization at start
            if content and not content[0].isupper():
                issues.append("no_start_capital")
                grammar_score -= 0.1
            
            # End punctuation
            if content.strip() and content.strip()[-1] not in '.!?':
                issues.append("no_end_punctuation")
                grammar_score -= 0.1
            
            # Multiple consecutive punctuation
            if re.search(r'[.!?]{2,}', content):
                issues.append("excessive_punctuation")
                grammar_score -= 0.1
            
            # All caps (shouting)
            if content.isupper():
                issues.append("all_caps")
                grammar_score -= 0.2
            
            # Multiple spaces
            if '  ' in content:
                issues.append("multiple_spaces")
                grammar_score -= 0.1
            
            # Check for common grammar patterns
            sentences = re.split(r'[.!?]+', content)
            for sentence in sentences:
                sentence = sentence.strip()
                if sentence and len(sentence.split()) < 3:
                    issues.append("fragment")
                    grammar_score -= 0.05
            
            return max(0.0, grammar_score)

        except Exception as e:
            logger.warning(f"Grammar assessment failed: {e}")
            return 0.0

    def _assess_readability(self, content: str) -> float:
        """Assess content readability"""
        try:
            # Simple readability metrics
            words = content.split()
            sentences = re.split(r'[.!?]+', content)
            
            if not words or not sentences:
                return 0.0
            
            avg_words_per_sentence = len(words) / len([s for s in sentences if s.strip()])
            
            readability_score = 1.0
            
            # Penalize very long sentences
            if avg_words_per_sentence > 25:
                readability_score -= 0.3
            elif avg_words_per_sentence > 20:
                readability_score -= 0.2
            elif avg_words_per_sentence > 15:
                readability_score -= 0.1
            
            # Penalize very short sentences
            if avg_words_per_sentence < 5:
                readability_score -= 0.2
            
            # Check word variety
            unique_words = set(word.lower().strip('.,!?') for word in words)
            variety_ratio = len(unique_words) / len(words) if words else 0
            
            if variety_ratio < 0.3:
                readability_score -= 0.2
            elif variety_ratio < 0.5:
                readability_score -= 0.1
            
            return max(0.0, readability_score)

        except Exception as e:
            logger.warning(f"Readability assessment failed: {e}")
            return 0.0

    def _assess_naturalness(self, content: str) -> float:
        """Assess how natural the content sounds"""
        try:
            naturalness_score = 1.0
            issues = []
            
            # Check for robotic phrases
            robotic_phrases = [
                "i am a bot",
                "as an ai",
                "i cannot",
                "i do not have",
                "artificial intelligence"
            ]
            
            content_lower = content.lower()
            for phrase in robotic_phrases:
                if phrase in content_lower:
                    issues.append("robotic_phrase")
                    naturalness_score -= 0.3
                    break
            
            # Check for repetitive patterns
            words = content.lower().split()
            word_freq = Counter(words)
            
            for word, freq in word_freq.items():
                if freq > len(words) * 0.2:  # Word appears more than 20% of the time
                    issues.append("repetitive")
                    naturalness_score -= 0.2
                    break
            
            # Check for unnatural capitalization
            if re.search(r'\b[A-Z]{3,}\b', content):
                issues.append("unnatural_caps")
                naturalness_score -= 0.2
            
            # Check for excessive formality
            formal_words = ["furthermore", "moreover", "henceforth", "wherein", "thereof"]
            formal_count = sum(1 for word in formal_words if word in content_lower)
            
            if formal_count > 2:
                issues.append("too_formal")
                naturalness_score -= 0.1
            
            return max(0.0, naturalness_score)

        except Exception as e:
            logger.warning(f"Naturalness assessment failed: {e}")
            return 0.0

    def _assess_coherence(self, content: str) -> float:
        """Assess content coherence and flow"""
        try:
            coherence_score = 1.0
            
            # Check for logical connectors
            connectors = [
                "because", "since", "therefore", "however", "although", "while",
                "also", "additionally", "furthermore", "moreover", "but", "and"
            ]
            
            content_lower = content.lower()
            connector_count = sum(1 for connector in connectors if connector in content_lower)
            
            # Some connectors are good, too many might be forced
            if connector_count == 0 and len(content.split()) > 20:
                coherence_score -= 0.2  # Long content without connectors
            elif connector_count > 5:
                coherence_score -= 0.1  # Too many connectors
            
            # Check for topic consistency (simplified)
            sentences = re.split(r'[.!?]+', content)
            sentences = [s.strip() for s in sentences if s.strip()]
            
            if len(sentences) > 1:
                # Simple check: do sentences share common words?
                words_sets = [set(sentence.lower().split()) for sentence in sentences]
                common_words = set.intersection(*words_sets) if words_sets else set()
                
                if len(common_words) == 0:
                    coherence_score -= 0.3  # No common words between sentences
            
            return max(0.0, coherence_score)

        except Exception as e:
            logger.warning(f"Coherence assessment failed: {e}")
            return 0.0

    def _assess_keyword_overlap(self, content: str, context: str) -> float:
        """Assess keyword overlap between content and context"""
        try:
            content_words = set(content.lower().split())
            context_words = set(context.lower().split())
            
            if not content_words or not context_words:
                return 0.0
            
            # Remove common stop words
            stop_words = {"the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "can", "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they"}
            
            content_words -= stop_words
            context_words -= stop_words
            
            if not content_words or not context_words:
                return 0.0
            
            overlap = content_words.intersection(context_words)
            overlap_ratio = len(overlap) / min(len(content_words), len(context_words))
            
            return min(1.0, overlap_ratio * 2)  # Scale up a bit

        except Exception as e:
            logger.warning(f"Keyword overlap assessment failed: {e}")
            return 0.0

    def _assess_topic_relevance(self, content: str, context: str) -> float:
        """Assess topic relevance (simplified)"""
        try:
            # Extract key terms from context
            context_words = context.lower().split()
            content_words = content.lower().split()
            
            # Look for important context words in content
            important_words = [word for word in context_words if len(word) > 4]
            
            if not important_words:
                return 0.5  # Neutral if no important words
            
            matches = sum(1 for word in important_words if word in content_words)
            relevance_score = matches / len(important_words)
            
            return min(1.0, relevance_score * 1.5)  # Scale up slightly

        except Exception as e:
            logger.warning(f"Topic relevance assessment failed: {e}")
            return 0.0

    def _assess_semantic_similarity(self, content: str, context: str) -> float:
        """Assess semantic similarity (simplified version)"""
        try:
            # Simple semantic similarity based on shared concepts
            content_set = set(content.lower().split())
            context_set = set(context.lower().split())
            
            if not content_set or not context_set:
                return 0.0
            
            intersection = content_set.intersection(context_set)
            union = content_set.union(context_set)
            
            jaccard_similarity = len(intersection) / len(union) if union else 0
            
            return jaccard_similarity

        except Exception as e:
            logger.warning(f"Semantic similarity assessment failed: {e}")
            return 0.0

    def _assess_anchor_inclusion(self, content: str, anchor: str) -> float:
        """Assess anchor text inclusion"""
        try:
            if not anchor:
                return 0.0
            
            if anchor.lower() in content.lower():
                return 1.0
            else:
                return 0.0

        except Exception as e:
            logger.warning(f"Anchor inclusion assessment failed: {e}")
            return 0.0

    def _assess_domain_inclusion(self, content: str, target_domain: str) -> float:
        """Assess domain inclusion"""
        try:
            if not target_domain:
                return 0.0
            
            # Extract domain name without TLD
            domain_parts = target_domain.split('.')
            domain_name = domain_parts[0].lower()
            
            if domain_name in content.lower():
                return 1.0
            elif target_domain.lower() in content.lower():
                return 1.0
            else:
                return 0.0

        except Exception as e:
            logger.warning(f"Domain inclusion assessment failed: {e}")
            return 0.0

    def _assess_natural_placement(self, content: str, anchor: str, target_domain: str) -> float:
        """Assess natural placement of anchor and domain"""
        try:
            if not anchor or not target_domain:
                return 0.0
            
            content_lower = content.lower()
            anchor_pos = content_lower.find(anchor.lower())
            domain_pos = content_lower.find(target_domain.lower())
            
            placement_score = 1.0
            
            # Check if both are present
            if anchor_pos == -1 or domain_pos == -1:
                return 0.0
            
            # Check if they're too close to each other (might look spammy)
            if abs(anchor_pos - domain_pos) < 10:
                placement_score -= 0.3
            
            # Check if they're at the very beginning or end
            if anchor_pos < 10 or domain_pos < 10:
                placement_score -= 0.2
            
            content_len = len(content)
            if anchor_pos > content_len - 10 or domain_pos > content_len - 10:
                placement_score -= 0.2
            
            return max(0.0, placement_score)

        except Exception as e:
            logger.warning(f"Natural placement assessment failed: {e}")
            return 0.0

    def _assess_link_context(self, content: str) -> float:
        """Assess context around the link"""
        try:
            # Look for contextual words around links
            contextual_words = [
                "check", "visit", "see", "find", "learn", "discover", "explore",
                "more", "information", "details", "resources", "guide", "help"
            ]
            
            content_lower = content.lower()
            context_count = sum(1 for word in contextual_words if word in content_lower)
            
            # More contextual words is better, up to a point
            if context_count >= 3:
                return 1.0
            elif context_count >= 2:
                return 0.8
            elif context_count >= 1:
                return 0.6
            else:
                return 0.3  # Some context but minimal

        except Exception as e:
            logger.warning(f"Link context assessment failed: {e}")
            return 0.0

    async def get_assessment_count(self) -> int:
        """Get total assessment count"""
        return self.assessment_count

    async def reset_count(self):
        """Reset assessment count"""
        self.assessment_count = 0
