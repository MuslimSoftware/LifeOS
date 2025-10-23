import Foundation

/// Defines JSON schemas for structured output extraction from OpenAI
/// Used with the structured outputs feature to ensure consistent format
struct ChunkAnalyticsSchema {

    /// JSON Schema for chunk analytics extraction
    /// Instructs the model to extract emotions, happiness metrics, and events from journal text
    static let schema: [String: Any] = [
        "name": "chunk_analytics",
        "description": "Analytics extracted from a journal entry chunk including emotions, happiness metrics, and events",
        "strict": true,
        "schema": [
            "type": "object",
            "properties": [
                "happiness": [
                    "type": "number",
                    "description": "Overall happiness score from 0-100, where 0 is very unhappy and 100 is extremely happy"
                ],
                "valence": [
                    "type": "number",
                    "description": "Emotional valence from -1 (very negative) to 1 (very positive)"
                ],
                "arousal": [
                    "type": "number",
                    "description": "Emotional arousal/activation from 0 (calm, low energy) to 1 (excited, activated, high energy)"
                ],
                "joy": [
                    "type": "number",
                    "description": "Joy emotion intensity from 0 (no joy) to 1 (intense joy)"
                ],
                "sadness": [
                    "type": "number",
                    "description": "Sadness emotion intensity from 0 (no sadness) to 1 (intense sadness)"
                ],
                "anger": [
                    "type": "number",
                    "description": "Anger emotion intensity from 0 (no anger) to 1 (intense anger)"
                ],
                "anxiety": [
                    "type": "number",
                    "description": "Anxiety emotion intensity from 0 (no anxiety) to 1 (intense anxiety)"
                ],
                "gratitude": [
                    "type": "number",
                    "description": "Gratitude emotion intensity from 0 (no gratitude) to 1 (intense gratitude)"
                ],
                "events": [
                    "type": "array",
                    "description": "List of significant events, activities, or experiences mentioned in the text",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": [
                                "type": "string",
                                "description": "Brief title for the event (3-8 words)"
                            ],
                            "description": [
                                "type": "string",
                                "description": "Optional detailed description of the event"
                            ],
                            "sentiment": [
                                "type": "string",
                                "enum": ["positive", "negative", "neutral"],
                                "description": "Emotional sentiment associated with this event"
                            ]
                        ],
                        "required": ["title", "description", "sentiment"],
                        "additionalProperties": false
                    ]
                ],
                "confidence": [
                    "type": "number",
                    "description": "Confidence in this analysis from 0 (very uncertain) to 1 (very confident). Lower if text is vague or ambiguous."
                ]
            ],
            "required": [
                "happiness",
                "valence",
                "arousal",
                "joy",
                "sadness",
                "anger",
                "anxiety",
                "gratitude",
                "events",
                "confidence"
            ],
            "additionalProperties": false
        ]
    ]

    /// System prompt for chunk analytics extraction
    static let systemPrompt = """
    You are an expert emotional intelligence analyst specializing in interpreting journal entries.

    Your task is to analyze journal text and extract:
    1. **Emotions**: Quantify joy, sadness, anger, anxiety, and gratitude (0-1 scale)
    2. **Happiness**: Overall happiness score (0-100)
    3. **Valence**: Emotional positivity from -1 (negative) to 1 (positive)
    4. **Arousal**: Emotional activation from 0 (calm) to 1 (excited)
    5. **Events**: Significant events, activities, or experiences mentioned
    6. **Confidence**: How confident you are in your analysis (0-1)

    Guidelines:
    - Be nuanced: Text can express mixed emotions
    - Context matters: Consider the overall tone and narrative
    - Events should be concrete and specific (e.g., "Had coffee with Sarah" not "social interaction")
    - Distinguish between current emotions and reflections on past emotions
    - If text is vague or minimal, lower your confidence score
    - Happiness should reflect overall well-being, not just momentary mood
    """
}
