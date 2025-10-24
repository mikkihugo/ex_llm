/**
 * @file Instructor Adapter for Structured LLM Outputs
 * @description Real Instructor library integration for TypeScript/Bun,
 * providing structured validation of tool outputs with automatic retry loops.
 *
 * Enables agentic workflows with validated, schema-compliant LLM outputs.
 *
 * @example
 * // Generate and validate code
 * const result = await InstructorAdapter.generateValidatedCode(
 *   "Create an async worker pattern",
 *   { language: "typescript", quality: "production" }
 * );
 * if (result.valid) {
 *   console.log(result.code);
 * }
 */

import Instructor from 'instructor';
import { createMistral } from '@ai-sdk/mistral'; // or anthropic, openai, etc.
import { z } from 'zod';

/**
 * Instructor schemas for structured LLM outputs
 */
export const InstructorSchemas = {
  /**
   * Generated code with quality metadata
   */
  GeneratedCode: z.object({
    code: z
      .string()
      .min(10, 'Code must be at least 10 characters')
      .max(50000, 'Code must be less than 50000 characters')
      .describe('The generated source code'),
    language: z
      .enum(['elixir', 'rust', 'typescript', 'python', 'go', 'java', 'c++'])
      .describe('Programming language'),
    quality_level: z
      .enum(['production', 'prototype', 'quick'])
      .describe('Quality level required'),
    has_docs: z.boolean().describe('Code includes documentation/comments'),
    has_tests: z.boolean().describe('Code includes test cases'),
    has_error_handling: z
      .boolean()
      .describe('Code handles errors appropriately'),
    estimated_lines: z
      .number()
      .int()
      .positive()
      .describe('Approximate number of code lines'),
  }),

  /**
   * Tool parameter validation result
   */
  ToolParameters: z.object({
    tool_name: z
      .string()
      .regex(/^[a-z_][a-z0-9_]*$/, 'Must be valid tool name')
      .describe('Name of the tool'),
    parameters: z
      .record(z.any())
      .describe('Map of parameter names to values'),
    valid: z.boolean().describe('Whether all parameters are valid'),
    errors: z.array(z.string()).describe('List of validation errors'),
  }),

  /**
   * Code quality assessment results
   */
  CodeQualityResult: z
    .object({
      score: z
        .number()
        .min(0, 'Score must be >= 0')
        .max(1, 'Score must be <= 1')
        .describe('Quality score from 0.0 to 1.0'),
      issues: z.array(z.string()).describe('List of identified quality issues'),
      suggestions: z
        .array(z.string())
        .describe('Suggestions for improvement'),
      passing: z.boolean().describe('Whether code passes minimum threshold'),
    })
    .refine(
      (data) => {
        // Score >= 0.8 means passing
        const expectedPassing = data.score >= 0.8;
        return data.passing === expectedPassing;
      },
      {
        message: 'Passing status must match score (>= 0.8 = passing)',
        path: ['passing'],
      }
    ),

  /**
   * Code refinement feedback
   */
  RefinementFeedback: z.object({
    focus_area: z
      .enum(['docs', 'tests', 'error_handling', 'performance', 'all'])
      .describe('What to focus on in refinement'),
    specific_issues: z
      .array(z.string())
      .min(1, 'Must have at least one issue')
      .describe('Exact issues to fix'),
    improvement_suggestions: z
      .array(z.string())
      .min(1, 'Must have at least one suggestion')
      .describe('How to improve'),
    effort_estimate: z
      .enum(['quick', 'moderate', 'extensive'])
      .optional()
      .describe('Effort needed for refinement'),
  }),

  /**
   * Code generation task specification
   */
  CodeGenerationTask: z.object({
    task_description: z
      .string()
      .min(10, 'Task must be at least 10 characters')
      .max(2000, 'Task must be less than 2000 characters')
      .describe('What code to generate'),
    language: z
      .enum(['elixir', 'rust', 'typescript', 'python', 'go', 'java', 'c++'])
      .describe('Target programming language'),
    quality_requirement: z
      .enum(['production', 'prototype', 'quick'])
      .describe('Quality level required'),
    context: z
      .string()
      .optional()
      .describe('Additional context or constraints'),
    example_patterns: z
      .array(z.string())
      .optional()
      .describe('Example code patterns to follow'),
  }),

  /**
   * Validation error details
   */
  ValidationError: z.object({
    field_name: z
      .string()
      .regex(/^[a-z_][a-z0-9_]*$/, 'Must be valid field identifier')
      .describe('Which field failed validation'),
    current_value: z.string().describe('The invalid value provided'),
    error_reason: z.string().describe('Why the value is invalid'),
    expected_format: z.string().describe('What format is expected'),
    correction_example: z.string().describe('Example of a valid value'),
  }),
};

/**
 * Type exports for TypeScript integration
 */
export type GeneratedCode = z.infer<typeof InstructorSchemas.GeneratedCode>;
export type ToolParameters = z.infer<typeof InstructorSchemas.ToolParameters>;
export type CodeQualityResult = z.infer<
  typeof InstructorSchemas.CodeQualityResult
>;
export type RefinementFeedback = z.infer<
  typeof InstructorSchemas.RefinementFeedback
>;
export type CodeGenerationTask = z.infer<
  typeof InstructorSchemas.CodeGenerationTask
>;
export type ValidationError = z.infer<typeof InstructorSchemas.ValidationError>;

/**
 * Instructor Adapter for structured validation with real Instructor library
 */
export class InstructorAdapter {
  private static client = Instructor({
    client: createMistral(), // Can switch to createAnthropic(), createOpenAI(), etc.
    mode: 'MD_JSON', // Use Markdown JSON mode for structured outputs
  });

  /**
   * Validate tool parameters with LLM feedback and automatic correction
   *
   * @param toolName Name of the tool
   * @param parameters Parameters to validate
   * @param options Validation options
   * @returns Validation result with errors if invalid
   */
  static async validateToolParameters(
    toolName: string,
    parameters: Record<string, unknown>,
    options: { max_retries?: number; model?: string } = {}
  ): Promise<ToolParameters> {
    const maxRetries = options.max_retries ?? 2;

    const prompt = `Validate these tool parameters for "${toolName}":
${JSON.stringify(parameters, null, 2)}

Check that:
1. All required parameters are present
2. Parameter types are appropriate
3. Values are valid for their intended use

Return validation results with detailed error messages if any validation fails.`;

    try {
      const result = await this.client.messages.create({
        model: options.model ?? 'mistral-large-latest',
        max_tokens: 1024,
        messages: [
          {
            role: 'user',
            content: prompt,
          },
        ],
        response_model: InstructorSchemas.ToolParameters as any,
      });

      return result as unknown as ToolParameters;
    } catch (error) {
      console.error(`Parameter validation failed for ${toolName}:`, error);
      return {
        tool_name: toolName,
        parameters: parameters,
        valid: false,
        errors: [
          `Validation error: ${error instanceof Error ? error.message : 'Unknown error'}`,
        ],
      };
    }
  }

  /**
   * Validate code quality with detailed feedback
   *
   * @param code Code to validate
   * @param language Programming language
   * @param quality Required quality level
   * @returns Quality assessment with score and feedback
   */
  static async validateCodeQuality(
    code: string,
    language: string,
    quality: 'production' | 'prototype' | 'quick'
  ): Promise<CodeQualityResult> {
    const qualityRequirements = {
      production:
        '- Must include comprehensive documentation\n- Must include test cases\n- Must handle errors appropriately\n- Code must be production-ready',
      prototype:
        '- Should include basic documentation\n- Should have basic error handling\n- Code should be functional and clear',
      quick:
        '- Basic code structure is acceptable\n- Documentation minimal but clear\n- Error handling basics present',
    };

    const prompt = `Assess the quality of this ${language} code:

\`\`\`${language}
${code}
\`\`\`

Quality Level Required: ${quality}

Requirements for ${quality} code:
${qualityRequirements[quality]}

Provide:
1. Overall quality score (0.0-1.0)
2. Specific issues found (list of strings)
3. Suggestions for improvement (list of strings)
4. Whether it passes the quality threshold (score >= 0.8)`;

    try {
      const result = await this.client.messages.create({
        model: 'mistral-large-latest',
        max_tokens: 2048,
        messages: [
          {
            role: 'user',
            content: prompt,
          },
        ],
        response_model: InstructorSchemas.CodeQualityResult as any,
      });

      return result as unknown as CodeQualityResult;
    } catch (error) {
      console.error('Code quality validation failed:', error);
      return {
        score: 0,
        issues: [`Validation error: ${error instanceof Error ? error.message : 'Unknown'}`],
        suggestions: [],
        passing: false,
      };
    }
  }

  /**
   * Refine code based on quality feedback with LLM
   *
   * @param code Current code
   * @param feedback Quality feedback
   * @param language Code language
   * @returns Refined code
   */
  static async refineCode(
    code: string,
    feedback: CodeQualityResult,
    language: string
  ): Promise<GeneratedCode> {
    const issuesText = feedback.issues.join('\n');
    const suggestionsText = feedback.suggestions.join('\n');

    const prompt = `Improve this ${language} code to address the following issues:

CURRENT CODE:
\`\`\`${language}
${code}
\`\`\`

IDENTIFIED ISSUES:
${issuesText}

IMPROVEMENT SUGGESTIONS:
${suggestionsText}

Return improved code that addresses all issues and suggestions.
Maintain the same functionality but fix quality problems.`;

    try {
      const result = await this.client.messages.create({
        model: 'mistral-large-latest',
        max_tokens: 4096,
        messages: [
          {
            role: 'user',
            content: prompt,
          },
        ],
        response_model: InstructorSchemas.GeneratedCode as any,
      });

      return result as unknown as GeneratedCode;
    } catch (error) {
      console.error('Code refinement failed:', error);
      throw error;
    }
  }

  /**
   * Generate code with validation in a loop until quality threshold met
   *
   * @param task Code generation task
   * @param options Generation options
   * @returns Generated and validated code with stats
   */
  static async generateValidatedCode(
    task: string,
    options: {
      language?: string;
      quality?: 'production' | 'prototype' | 'quick';
      quality_threshold?: number;
      max_iterations?: number;
    } = {}
  ): Promise<{
    valid: boolean;
    code?: string;
    score?: number;
    iterations: number;
    final: boolean;
    reason?: string;
  }> {
    const language = options.language ?? 'typescript';
    const quality = options.quality ?? 'production';
    const threshold = options.quality_threshold ?? 0.85;
    const maxIterations = options.max_iterations ?? 3;

    let currentCode: string | undefined;
    let iteration = 0;

    for (iteration = 0; iteration < maxIterations; iteration++) {
      try {
        // Generate code
        const generationPrompt =
          iteration === 0
            ? `Generate ${language} code for: ${task}`
            : `Generate improved ${language} code for: ${task}. Previous attempts were not good enough.`;

        const generated = await this.client.messages.create({
          model: 'mistral-large-latest',
          max_tokens: 4096,
          messages: [
            {
              role: 'user',
              content: generationPrompt,
            },
          ],
          response_model: InstructorSchemas.GeneratedCode as any,
        });

        currentCode = (generated as unknown as GeneratedCode).code;

        // Validate
        const quality_result = await this.validateCodeQuality(
          currentCode,
          language,
          quality
        );

        if (quality_result.score >= threshold && quality_result.passing) {
          return {
            valid: true,
            code: currentCode,
            score: quality_result.score,
            iterations: iteration + 1,
            final: true,
          };
        }

        // Try to refine if not passing
        if (iteration < maxIterations - 1) {
          try {
            const refined = await this.refineCode(
              currentCode,
              quality_result,
              language
            );
            currentCode = refined.code;
          } catch (refineError) {
            console.warn('Refinement failed, continuing with current code');
          }
        }
      } catch (error) {
        console.error(`Generation failed at iteration ${iteration}:`, error);
        if (iteration === 0) {
          return {
            valid: false,
            iterations: 1,
            final: false,
            reason: `Generation failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
          };
        }
      }
    }

    // Max iterations reached
    return {
      valid: false,
      code: currentCode,
      iterations: maxIterations,
      final: false,
      reason: `Max iterations (${maxIterations}) reached without meeting quality threshold (${threshold})`,
    };
  }

  /**
   * Validate generation task specification
   *
   * @param task Task to validate
   * @returns Validation result
   */
  static validateGenerationTask(task: Partial<CodeGenerationTask>): {
    valid: boolean;
    errors: string[];
    task?: CodeGenerationTask;
  } {
    // Use reasonable defaults for validation
    const taskWithDefaults: Partial<CodeGenerationTask> = {
      language: task.language ?? 'typescript',
      quality_requirement: task.quality_requirement ?? 'production',
      ...task,
    };

    const result = InstructorSchemas.CodeGenerationTask.safeParse(taskWithDefaults);

    if (!result.success) {
      return {
        valid: false,
        errors: result.error.errors.map((err) => `${err.path.join('.')}: ${err.message}`),
      };
    }

    return {
      valid: true,
      errors: [],
      task: result.data,
    };
  }

  /**
   * Validate generated code against schema
   *
   * @param code Generated code
   * @param metadata Code metadata
   * @returns Validation result
   */
  static validateGeneratedCode(
    code: string,
    metadata: Partial<GeneratedCode> = {}
  ): {
    valid: boolean;
    errors: string[];
    code?: GeneratedCode;
  } {
    const codeWithDefaults: Partial<GeneratedCode> = {
      language: 'typescript',
      quality_level: 'production',
      has_docs: false,
      has_tests: false,
      has_error_handling: false,
      estimated_lines: code.split('\n').length,
      ...metadata,
      code,
    };

    const result = InstructorSchemas.GeneratedCode.safeParse(codeWithDefaults);

    if (!result.success) {
      return {
        valid: false,
        errors: result.error.errors.map((err) => `${err.path.join('.')}: ${err.message}`),
      };
    }

    return {
      valid: true,
      errors: [],
      code: result.data,
    };
  }
}

/**
 * Validation utility functions
 */
export const InstructorValidation = {
  /**
   * Check if code passes production quality threshold
   */
  isProductionReady: (quality: CodeQualityResult): boolean => {
    return quality.passing && quality.score >= 0.85;
  },

  /**
   * Format validation error for display
   */
  formatError: (error: ValidationError): string => {
    return `Field '${error.field_name}': ${error.error_reason}\nExpected: ${error.expected_format}\nExample: ${error.correction_example}`;
  },

  /**
   * Format quality result for logging
   */
  formatQualityResult: (result: CodeQualityResult): string => {
    return `Quality: ${(result.score * 100).toFixed(1)}% ${result.passing ? '✓ PASS' : '✗ FAIL'}\nIssues: ${result.issues.length}\nSuggestions: ${result.suggestions.length}`;
  },
};
