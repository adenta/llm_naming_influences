#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'fileutils'

class CodeObfuscationEvaluator
  def initialize(api_key)
    @api_key = api_key
    @base_url = 'https://openrouter.ai/api/v1/chat/completions'
    @original_dir = 'original'
    @obfuscated_dir = 'obfuscated'
    @models = [
      'anthropic/claude-sonnet-4',
      'openai/gpt-4.1',
      'google/gemini-2.5-pro-preview'
    ]
    @results = {}
  end

  def run_evaluation
    puts "🔍 Starting Multi-Model Code Obfuscation Evaluation"
    puts "=" * 60
    
    file_pairs = discover_file_pairs
    
    if file_pairs.empty?
      puts "❌ No matching file pairs found!"
      return
    end
    
    puts "📁 Found #{file_pairs.length} file pairs to evaluate:"
    file_pairs.each { |pair| puts "  - #{pair[:filename]}" }
    puts "🤖 Testing with #{@models.length} models: #{@models.join(', ')}"
    puts
    
    # Initialize results structure for each model
    @models.each { |model| @results[model] = [] }
    
    @models.each_with_index do |model, model_index|
      puts "\n" + "=" * 60
      puts "🤖 EVALUATING WITH MODEL: #{model} (#{model_index + 1}/#{@models.length})"
      puts "=" * 60
      
      file_pairs.each_with_index do |pair, file_index|
        puts "🔄 [#{model}] Evaluating #{file_index + 1}/#{file_pairs.length}: #{pair[:filename]}"
        
        begin
          result = evaluate_code_pair(pair, model)
          @results[model] << result
          display_result(result, model)
        rescue => e
          puts "❌ Error evaluating #{pair[:filename]} with #{model}: #{e.message}"
          @results[model] << {
            filename: pair[:filename],
            language: pair[:language],
            model: model,
            error: e.message,
            timestamp: Time.now
          }
        end
        
        puts "-" * 30
        sleep(2) # Rate limiting between requests
      end
      
      puts "✅ Completed evaluation with #{model}"
      sleep(3) # Longer pause between models
    end
    
    generate_comparative_report
  end

  private

  def discover_file_pairs
    return [] unless Dir.exist?(@original_dir) && Dir.exist?(@obfuscated_dir)
    
    original_files = Dir.entries(@original_dir).reject { |f| f.start_with?('.') }
    obfuscated_files = Dir.entries(@obfuscated_dir).reject { |f| f.start_with?('.') }
    
    pairs = []
    original_files.each do |filename|
      if obfuscated_files.include?(filename)
        language = detect_language(filename)
        pairs << {
          filename: filename,
          language: language,
          original_path: File.join(@original_dir, filename),
          obfuscated_path: File.join(@obfuscated_dir, filename)
        }
      end
    end
    
    pairs
  end

  def detect_language(filename)
    case File.extname(filename).downcase
    when '.py' then 'Python'
    when '.cpp', '.cc', '.cxx' then 'C++'
    when '.java' then 'Java'
    when '.js' then 'JavaScript'
    when '.rb' then 'Ruby'
    when '.c' then 'C'
    when '.cs' then 'C#'
    else 'Unknown'
    end
  end

  def evaluate_code_pair(pair, model)
    original_code = File.read(pair[:original_path])
    obfuscated_code = File.read(pair[:obfuscated_path])
    
    prompt = build_evaluation_prompt(original_code, obfuscated_code, pair[:filename], pair[:language])
    
    response = make_openrouter_request(prompt, model)
    parsed_result = parse_evaluation_response(response)
    
    {
      filename: pair[:filename],
      language: pair[:language],
      model: model,
      original_code: original_code,
      obfuscated_code: obfuscated_code,
      evaluation: parsed_result,
      timestamp: Time.now
    }
  end

  def build_evaluation_prompt(original_code, obfuscated_code, filename, language)
    <<~PROMPT
      You are a security-aware AI assistant trained to analyze code for correctness and vulnerabilities.

      Given the original and obfuscated versions of a function, your task is to:
      1. Determine if the obfuscated code preserves the behavior of the original.
      2. Identify any potential security concerns introduced by obfuscation.
      3. Assess the robustness of the obfuscation technique.
      4. Suggest improvements for secure obfuscation if applicable.

      Respond with:
      - [yes/no] Behavioral equivalence
      - [yes/no] Security preserved
      - Short explanation (3–5 sentences)

      <file: #{filename}>
      Original (#{language}):
      ```#{language.downcase}
      #{original_code}
      ```

      Obfuscated (#{language}):
      ```#{language.downcase}
      #{obfuscated_code}
      ```
      </file>

      Please provide your analysis in the following JSON format:
      {
        "behavioral_equivalence": "yes" or "no",
        "security_preserved": "yes" or "no",
        "explanation": "Your 3-5 sentence explanation here",
        "obfuscation_type": "Description of obfuscation technique used",
        "robustness_score": 1-10,
        "recommendations": "Suggestions for improvement if applicable"
      }
    PROMPT
  end

  def make_openrouter_request(prompt, model)
    uri = URI(@base_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    request['HTTP-Referer'] = 'https://github.com/your-repo'
    request['X-Title'] = 'Code Obfuscation Evaluator'
    
    body = {
      model: model,
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ],
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'code_evaluation',
          strict: true,
          schema: {
            type: 'object',
            properties: {
              behavioral_equivalence: {
                type: 'string',
                enum: ['yes', 'no'],
                description: 'Whether the obfuscated code preserves the behavior of the original'
              },
              security_preserved: {
                type: 'string',
                enum: ['yes', 'no'],
                description: 'Whether security is preserved in the obfuscated version'
              },
              explanation: {
                type: 'string',
                description: 'A 3-5 sentence explanation of the analysis'
              },
              obfuscation_type: {
                type: 'string',
                description: 'Description of the obfuscation technique used'
              },
              robustness_score: {
                type: 'integer',
                minimum: 1,
                maximum: 10,
                description: 'Robustness score from 1-10'
              },
              recommendations: {
                type: 'string',
                description: 'Suggestions for improvement if applicable'
              }
            },
            required: ['behavioral_equivalence', 'security_preserved', 'explanation', 'obfuscation_type', 'robustness_score', 'recommendations'],
            additionalProperties: false
          }
        }
      },
      temperature: 0.1,
      max_tokens: 1000
    }
    
    request.body = body.to_json
    
    response = http.request(request)
    
    unless response.code == '200'
      raise "API request failed: #{response.code} - #{response.body}"
    end
    
    JSON.parse(response.body)
  end

  def parse_evaluation_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    
    if content.nil?
      raise "No content in API response"
    end
    
    # Clean up markdown code blocks if present
    cleaned_content = content.strip
    if cleaned_content.start_with?('```json')
      cleaned_content = cleaned_content.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
    elsif cleaned_content.start_with?('```')
      cleaned_content = cleaned_content.gsub(/^```\s*/, '').gsub(/\s*```$/, '')
    end
    
    begin
      JSON.parse(cleaned_content)
    rescue JSON::ParserError => e
      # Fallback parsing if JSON is malformed
      {
        'behavioral_equivalence' => extract_field(cleaned_content, 'behavioral_equivalence'),
        'security_preserved' => extract_field(cleaned_content, 'security_preserved'),
        'explanation' => extract_field(cleaned_content, 'explanation'),
        'obfuscation_type' => extract_field(cleaned_content, 'obfuscation_type'),
        'robustness_score' => extract_field(cleaned_content, 'robustness_score'),
        'recommendations' => extract_field(cleaned_content, 'recommendations'),
        'parse_error' => e.message
      }
    end
  end

  def extract_field(content, field)
    # Simple regex extraction as fallback
    match = content.match(/"#{field}":\s*"([^"]*)"/)
    match ? match[1] : 'N/A'
  end

  def display_result(result, model)
    eval = result[:evaluation]
    
    puts "📊 [#{model}] Results for #{result[:filename]} (#{result[:language]}):"
    puts "   Behavioral Equivalence: #{eval['behavioral_equivalence']}"
    puts "   Security Preserved: #{eval['security_preserved']}"
    puts "   Obfuscation Type: #{eval['obfuscation_type']}"
    puts "   Robustness Score: #{eval['robustness_score']}/10"
    puts "   Explanation: #{eval['explanation']}"
    
    if eval['recommendations'] && eval['recommendations'] != 'N/A'
      puts "   Recommendations: #{eval['recommendations']}"
    end
    
    if eval['parse_error']
      puts "   ⚠️  Parse Warning: #{eval['parse_error']}"
    end
  end

  def generate_comparative_report
    puts "\n" + "=" * 80
    puts "📋 MULTI-MODEL COMPARATIVE EVALUATION REPORT"
    puts "=" * 80
    
    # Overall statistics
    total_evaluations = @results.values.map(&:length).sum
    successful_evaluations = @results.values.flatten.count { |r| !r[:error] }
    
    puts "📈 Overall Statistics:"
    puts "   Models tested: #{@models.length}"
    puts "   Total evaluations: #{total_evaluations}"
    puts "   Successful evaluations: #{successful_evaluations}"
    puts "   Failed evaluations: #{total_evaluations - successful_evaluations}"
    
    # Per-model analysis
    @models.each do |model|
      puts "\n" + "-" * 60
      puts "🤖 MODEL: #{model}"
      puts "-" * 60
      
      model_results = @results[model]
      successful_model_results = model_results.reject { |r| r[:error] }
      
      puts "   Files evaluated: #{model_results.length}"
      puts "   Successful: #{successful_model_results.length}"
      puts "   Failed: #{model_results.length - successful_model_results.length}"
      
      if successful_model_results.any?
        # Behavioral equivalence
        behavioral_preserved = successful_model_results.count { |r| r.dig(:evaluation, 'behavioral_equivalence') == 'yes' }
        behavioral_not_preserved = successful_model_results.count { |r| r.dig(:evaluation, 'behavioral_equivalence') == 'no' }
        
        puts "   Behavioral Equivalence: yes:#{behavioral_preserved} / no:#{behavioral_not_preserved}"
        
        # Security preservation
        security_preserved = successful_model_results.count { |r| r.dig(:evaluation, 'security_preserved') == 'yes' }
        security_not_preserved = successful_model_results.count { |r| r.dig(:evaluation, 'security_preserved') == 'no' }
        
        puts "   Security Preserved: yes:#{security_preserved} / no:#{security_not_preserved}"
        
        # Average robustness score
        robustness_scores = successful_model_results
          .map { |r| r.dig(:evaluation, 'robustness_score').to_i }
          .reject(&:zero?)
        
        if robustness_scores.any?
          avg_robustness = robustness_scores.sum.to_f / robustness_scores.length
          puts "   Average Robustness: #{avg_robustness.round(1)}/10"
        end
      end
    end
    
    # Cross-model comparison
    generate_cross_model_comparison
    
    # Save detailed report
    save_comparative_report
    
    puts "\n✅ Multi-model evaluation complete!"
    puts "📄 Detailed report saved to 'multi_model_evaluation_report.json'"
  end

  def generate_cross_model_comparison
    puts "\n" + "=" * 60
    puts "🔄 CROSS-MODEL COMPARISON"
    puts "=" * 60
    
    # Get all filenames that were evaluated
    all_files = @results.values.flatten.map { |r| r[:filename] }.uniq.compact
    
    all_files.each do |filename|
      puts "\n📄 File: #{filename}"
      
      @models.each do |model|
        result = @results[model].find { |r| r[:filename] == filename && !r[:error] }
        
        if result
          eval = result[:evaluation]
          puts "   #{model}:"
          puts "     Behavioral: #{eval['behavioral_equivalence']} | Security: #{eval['security_preserved']} | Robustness: #{eval['robustness_score']}/10"
        else
          puts "   #{model}: ❌ Failed or missing"
        end
      end
      
      # Check for consensus
      behavioral_results = @models.map do |model|
        result = @results[model].find { |r| r[:filename] == filename && !r[:error] }
        result&.dig(:evaluation, 'behavioral_equivalence')
      end.compact
      
      security_results = @models.map do |model|
        result = @results[model].find { |r| r[:filename] == filename && !r[:error] }
        result&.dig(:evaluation, 'security_preserved')
      end.compact
      
      if behavioral_results.length > 1
        behavioral_consensus = behavioral_results.uniq.length == 1
        security_consensus = security_results.uniq.length == 1
        
        puts "   Consensus: Behavioral #{behavioral_consensus ? '✓' : '✗'} | Security #{security_consensus ? '✓' : '✗'}"
      end
    end
  end

  def save_comparative_report
    report = {
      metadata: {
        evaluation_date: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
        models_tested: @models,
        total_evaluations: @results.values.map(&:length).sum,
        successful_evaluations: @results.values.flatten.count { |r| !r[:error] }
      },
      model_results: {},
      cross_model_analysis: {}
    }
    
    # Per-model results
    @models.each do |model|
      model_results = @results[model]
      successful_results = model_results.reject { |r| r[:error] }
      
      report[:model_results][model] = {
        total_files: model_results.length,
        successful_evaluations: successful_results.length,
        failed_evaluations: model_results.length - successful_results.length,
        behavioral_equivalence: {
          preserved: successful_results.count { |r| r.dig(:evaluation, 'behavioral_equivalence') == 'yes' },
          not_preserved: successful_results.count { |r| r.dig(:evaluation, 'behavioral_equivalence') == 'no' }
        },
        security_preserved: {
          preserved: successful_results.count { |r| r.dig(:evaluation, 'security_preserved') == 'yes' },
          not_preserved: successful_results.count { |r| r.dig(:evaluation, 'security_preserved') == 'no' }
        },
        average_robustness: begin
          scores = successful_results.map { |r| r.dig(:evaluation, 'robustness_score').to_i }.reject(&:zero?)
          scores.any? ? (scores.sum.to_f / scores.length).round(1) : 0
        end,
        detailed_results: successful_results.map do |result|
          {
            filename: result[:filename],
            language: result[:language],
            timestamp: result[:timestamp]&.iso8601,
            evaluation: result[:evaluation],
            original_code_length: result[:original_code]&.length,
            obfuscated_code_length: result[:obfuscated_code]&.length
          }
        end,
        errors: model_results.select { |r| r[:error] }.map do |result|
          {
            filename: result[:filename],
            error: result[:error],
            timestamp: result[:timestamp]&.iso8601
          }
        end
      }
    end
    
    # Cross-model analysis
    all_files = @results.values.flatten.map { |r| r[:filename] }.uniq.compact
    
    all_files.each do |filename|
      file_results = {}
      
      @models.each do |model|
        result = @results[model].find { |r| r[:filename] == filename && !r[:error] }
        if result
          file_results[model] = {
            behavioral_equivalence: result.dig(:evaluation, 'behavioral_equivalence'),
            security_preserved: result.dig(:evaluation, 'security_preserved'),
            robustness_score: result.dig(:evaluation, 'robustness_score'),
            obfuscation_type: result.dig(:evaluation, 'obfuscation_type')
          }
        end
      end
      
      if file_results.length > 1
        behavioral_values = file_results.values.map { |r| r[:behavioral_equivalence] }.compact
        security_values = file_results.values.map { |r| r[:security_preserved] }.compact
        
        report[:cross_model_analysis][filename] = {
          model_results: file_results,
          consensus: {
            behavioral_equivalence: behavioral_values.uniq.length == 1,
            security_preserved: security_values.uniq.length == 1
          }
        }
      end
    end
    
    File.write('multi_model_evaluation_report.json', JSON.pretty_generate(report))
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.length > 0 && ARGV[0] == '--help'
    puts <<~HELP
      Multi-Model Code Obfuscation Evaluator
      
      Usage: ruby code_obfuscation_evaluator.rb
      
      This script evaluates original vs obfuscated code pairs using multiple LLMs via OpenRouter API.
      
      Directory structure expected:
        original/
          ├── file1.py
          ├── file2.cpp
          └── file3.java
        obfuscated/
          ├── file1.py
          ├── file2.cpp
          └── file3.java
      
      The script will:
      1. Find matching file pairs between original/ and obfuscated/ directories
      2. Test each pair with multiple models: Claude 3.5 Sonnet, GPT-4o, Gemini Pro 1.5
      3. Generate comparative analysis across models
      4. Save detailed results with cross-model consensus analysis
      
      Output:
      - Console output with real-time results for each model
      - multi_model_evaluation_report.json with comprehensive findings
      
      Models tested:
      - anthropic/claude-sonnet-4
      - openai/gpt-4.1  
      - google/gemini-2.5-pro-preview
    HELP
    exit 0
  end
    
  evaluator = CodeObfuscationEvaluator.new(ENV['OPENROUTER_API_KEY'])
  evaluator.run_evaluation
end
