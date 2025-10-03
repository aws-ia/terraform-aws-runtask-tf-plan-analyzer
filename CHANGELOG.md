# Changelog

## [Unreleased]

## [1.0.0] - 2025-10-03

### Added
- Enhanced AI analysis with structured impact assessment including security concerns, configuration issues, operational impact, and recommendations
- Improved error handling and JSON parsing for Bedrock responses
- Better AMI analysis with direct technical output

### Changed
- **BREAKING**: Updated default Bedrock model from `anthropic.claude-3-sonnet-20240229-v1:0` to `global.anthropic.claude-sonnet-4-20250514-v1:0` (supports cross-region inference profiles)
- Increased default Lambda timeout from 120 seconds to 300 seconds for better performance with Claude 4.0
- Restructured AI prompts for more focused and technical analysis output
- Improved system prompts to reduce conversational language in responses
- Enhanced JSON response parsing with better error handling and fallback mechanisms
