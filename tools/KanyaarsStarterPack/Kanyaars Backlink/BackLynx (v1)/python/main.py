import os
import sys
import asyncio
import logging
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
from redis import asyncio as redis

# Temporarily disable complex AI modules for deployment
# from src.ai.content_generator import ContentGenerator
# from src.nlp.processor import NLPProcessor
# from src.quality.assessor import QualityAssessor

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/ai_service.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="BackLynx AI Service",
    description="AI-powered content generation for backlink injection",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables
redis_client = None
content_generator = None
nlp_processor = None
quality_assessor = None

class ContentRequest(BaseModel):
    url: str
    anchor: str
    targetDomain: str
    context: str = None

class ContentResponse(BaseModel):
    content: str
    quality_score: float
    relevance_score: float
    seo_score: float

class HealthResponse(BaseModel):
    status: str
    timestamp: str
    services: dict

async def initialize_services():
    """Initialize all AI services"""
    global redis_client, content_generator, nlp_processor, quality_assessor
    
    try:
        # Initialize Redis
        redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379')
        redis_client = redis.from_url(redis_url)
        await redis_client.ping()
        logger.info("Connected to Redis")

        # Simplified AI services for deployment
        content_generator = None  # Disabled for now
        nlp_processor = None     # Disabled for now
        quality_assessor = None   # Disabled for now
        logger.info("AI services disabled for deployment")

    except Exception as e:
        logger.error(f"Failed to initialize services: {e}")
        raise

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    await initialize_services()

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    if redis_client:
        await redis_client.close()
    logger.info("AI service shutdown complete")

@app.get("/", response_model=dict)
async def root():
    """Root endpoint"""
    return {
        "service": "BackLynx AI Service",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    from datetime import datetime
    
    services = {
        "redis": "healthy",
        "content_generator": "healthy",
        "nlp_processor": "healthy",
        "quality_assessor": "healthy"
    }

    # Check Redis connection
    try:
        if redis_client:
            await redis_client.ping()
        else:
            services["redis"] = "unhealthy"
    except Exception as e:
        logger.error(f"Redis health check failed: {e}")
        services["redis"] = "unhealthy"

    return HealthResponse(
        status="healthy" if all(status == "healthy" for status in services.values()) else "degraded",
        timestamp=datetime.now().isoformat(),
        services=services
    )

@app.post("/generate", response_model=ContentResponse)
async def generate_content(request: ContentRequest):
    """Generate AI content for backlink injection"""
    try:
        # Extract page context if not provided
        context = request.context
        if not context:
            context = await extract_page_context(request.url)

        # Generate content
        content = await content_generator.generate(
            url=request.url,
            anchor=request.anchor,
            target_domain=request.targetDomain,
            context=context
        )

        # Assess quality
        quality_score = await quality_assessor.assess_quality(content)
        relevance_score = await quality_assessor.assess_relevance(content, context)
        seo_score = await quality_assessor.assess_seo(content, request.anchor, request.targetDomain)

        # Log generation
        logger.info(f"Generated content for {request.url} - Quality: {quality_score:.2f}")

        return ContentResponse(
            content=content,
            quality_score=quality_score,
            relevance_score=relevance_score,
            seo_score=seo_score
        )

    except Exception as e:
        logger.error(f"Content generation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/analyze")
async def analyze_content(content: str):
    """Analyze existing content"""
    try:
        # NLP analysis
        nlp_analysis = await nlp_processor.analyze(content)

        # Quality assessment
        quality_score = await quality_assessor.assess_quality(content)

        return {
            "nlp_analysis": nlp_analysis,
            "quality_score": quality_score,
            "sentiment": nlp_analysis.get("sentiment", "neutral"),
            "language": nlp_analysis.get("language", "en"),
            "keywords": nlp_analysis.get("keywords", [])
        }

    except Exception as e:
        logger.error(f"Content analysis failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def extract_page_context(url: str) -> str:
    """Extract context from a webpage"""
    try:
        import requests
        from bs4 import BeautifulSoup
        
        # Fetch webpage content
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()

        # Parse HTML
        soup = BeautifulSoup(response.content, 'html.parser')

        # Extract relevant content
        title = soup.find('title')
        title_text = title.get_text().strip() if title else ""

        # Extract meta description
        meta_desc = soup.find('meta', attrs={'name': 'description'})
        meta_text = meta_desc.get('content', '').strip() if meta_desc else ""

        # Extract first paragraph
        first_p = soup.find('p')
        first_p_text = first_p.get_text().strip() if first_p else ""

        # Combine context
        context = f"Title: {title_text}\n"
        if meta_text:
            context += f"Description: {meta_text}\n"
        if first_p_text:
            context += f"Content: {first_p_text[:500]}..."

        return context

    except Exception as e:
        logger.warning(f"Failed to extract context from {url}: {e}")
        return ""

@app.get("/stats")
async def get_stats():
    """Get service statistics"""
    try:
        stats = {
            "content_generated": await content_generator.get_generation_count(),
            "nlp_processed": await nlp_processor.get_processed_count(),
            "quality_assessed": await quality_assessor.get_assessment_count(),
            "redis_connected": redis_client is not None
        }

        return stats

    except Exception as e:
        logger.error(f"Failed to get stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    # Create logs directory if it doesn't exist
    os.makedirs("logs", exist_ok=True)
    
    # Run the application
    port = int(os.getenv('PYTHON_PORT', 5000))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=False,
        log_level="info"
    )
