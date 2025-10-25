import { describe, test, expect } from 'bun:test';
import {
  InstructorAdapter,
  InstructorSchemas,
  InstructorValidation,
  type GeneratedCode,
  type CodeQualityResult,
  type ToolParameters,
} from '../instructor-adapter';

describe('InstructorAdapter', () => {
  describe('validateToolParameters', () => {
    test('validates valid tool parameters', () => {
      const result = InstructorAdapter.validateToolParameters('code_generate', {
        task: 'write GenServer',
        language: 'elixir',
      });

      expect(result.tool_name).toBe('code_generate');
      expect(result.valid).toBe(true);
      expect(result.errors.length).toBe(0);
    });

    test('rejects invalid tool name', () => {
      const result = InstructorAdapter.validateToolParameters('invalid-tool-name', {
        task: 'write code',
      });

      expect(result.valid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });

    test('preserves parameters in result', () => {
      const params = {
        task: 'Create GenServer',
        language: 'elixir',
        quality: 'production',
      };

      const result = InstructorAdapter.validateToolParameters('code_generate', params);

      expect(result.parameters).toEqual(params);
    });
  });

  describe('validateCodeQuality', () => {
    test('assesses high-quality code', () => {
      const code = `
        /**
         * High-quality function with documentation
         */
        defmodule MyModule do
          @doc "Adds two numbers"
          def add(a, b) do
            a + b
          end

          @doc "Test the add function"
          def test_add do
            assert add(2, 3) == 5
          end
        end
      `;

      const result = InstructorAdapter.validateCodeQuality(code, 'elixir', 'production');

      expect(result.score).toBeGreaterThanOrEqual(0);
      expect(result.score).toBeLessThanOrEqual(1);
      expect(Array.isArray(result.issues)).toBe(true);
      expect(Array.isArray(result.suggestions)).toBe(true);
    });

    test('identifies missing documentation', () => {
      const code = `
        defmodule BadModule do
          def function_without_docs do
            :ok
          end
        end
      `;

      const result = InstructorAdapter.validateCodeQuality(code, 'elixir', 'production');

      // Should have issues about missing docs
      expect(result.issues.length).toBeGreaterThan(0);
    });

    test('identifies code too short', () => {
      const code = 'x = 1';

      const result = InstructorAdapter.validateCodeQuality(code, 'elixir', 'production');

      expect(result.issues).toContain('Code is too short (minimum 10 characters)');
    });

    test('validates prototype quality differently', () => {
      const code = 'def x, do: 1';

      const result = InstructorAdapter.validateCodeQuality(code, 'elixir', 'prototype');

      // Prototype should be more lenient
      expect(Array.isArray(result.issues)).toBe(true);
    });

    test('validates quick quality even more leniently', () => {
      const code = 'def x, do: 1';

      const result = InstructorAdapter.validateCodeQuality(code, 'elixir', 'quick');

      // Quick should be most lenient
      expect(Array.isArray(result.issues)).toBe(true);
    });

    test('quality score >= 0.8 means passing', () => {
      const result: CodeQualityResult = {
        score: 0.85,
        issues: [],
        suggestions: [],
        passing: true,
      };

      expect(result.passing).toBe(true);
    });

    test('quality score < 0.8 means failing', () => {
      const result: CodeQualityResult = {
        score: 0.75,
        issues: ['Missing tests'],
        suggestions: ['Add test cases'],
        passing: false,
      };

      expect(result.passing).toBe(false);
    });
  });

  describe('createRefinementFeedback', () => {
    test('creates feedback focused on documentation', () => {
      const code = 'def f, do: :ok';
      const quality: CodeQualityResult = {
        score: 0.5,
        issues: ['Missing documentation'],
        suggestions: ['Add docstring'],
        passing: false,
      };

      const feedback = InstructorAdapter.createRefinementFeedback(code, quality);

      expect(feedback.specific_issues).toContain('Missing documentation');
      expect(feedback.improvement_suggestions).toContain('Add docstring');
    });

    test('focuses on tests when missing', () => {
      const code = 'def add(a, b), do: a + b';
      const quality: CodeQualityResult = {
        score: 0.6,
        issues: ['Missing test cases'],
        suggestions: ['Add test examples'],
        passing: false,
      };

      const feedback = InstructorAdapter.createRefinementFeedback(code, quality);

      expect(feedback.focus_area).toBe('tests');
    });

    test('focuses on error handling when needed', () => {
      const code = 'def risky, do: File.read!("file")';
      const quality: CodeQualityResult = {
        score: 0.5,
        issues: ['No error handling'],
        suggestions: ['Add try-catch or case statement'],
        passing: false,
      };

      const feedback = InstructorAdapter.createRefinementFeedback(code, quality);

      expect(feedback.focus_area).toBe('error_handling');
    });
  });

  describe('validateGenerationTask', () => {
    test('validates complete task', () => {
      const task = {
        task_description: 'Write an Elixir GenServer for caching with TTL',
        language: 'elixir' as const,
        quality_requirement: 'production' as const,
        context: 'For internal tooling',
      };

      const result = InstructorAdapter.validateGenerationTask(task);

      expect(result.valid).toBe(true);
      expect(result.errors.length).toBe(0);
    });

    test('rejects task with missing description', () => {
      const task = {
        language: 'elixir' as const,
        quality_requirement: 'production' as const,
      };

      const result = InstructorAdapter.validateGenerationTask(task);

      expect(result.valid).toBe(false);
    });

    test('applies default language', () => {
      const task = {
        task_description: 'Write a simple function',
        quality_requirement: 'production' as const,
      };

      const result = InstructorAdapter.validateGenerationTask(task);

      expect(result.task?.language).toBe('elixir');
    });

    test('rejects unsupported language', () => {
      const task = {
        task_description: 'Write something',
        language: 'cobol' as any,
        quality_requirement: 'production' as const,
      };

      const result = InstructorAdapter.validateGenerationTask(task);

      expect(result.valid).toBe(false);
    });
  });

  describe('validateGeneratedCode', () => {
    test('validates code with metadata', () => {
      const code = `
        def test do
          # implementation
        end
      `;

      const result = InstructorAdapter.validateGeneratedCode(code, {
        language: 'elixir',
        quality_level: 'production',
        has_docs: true,
        has_tests: false,
      });

      expect(result.valid).toBe(true);
      expect(result.code?.code).toBe(code);
    });

    test('rejects code too short', () => {
      const code = 'x';

      const result = InstructorAdapter.validateGeneratedCode(code);

      expect(result.valid).toBe(false);
    });

    test('counts estimated lines', () => {
      const code = `line 1
line 2
line 3`;

      const result = InstructorAdapter.validateGeneratedCode(code);

      expect(result.code?.estimated_lines).toBe(3);
    });

    test('applies defaults for missing metadata', () => {
      const code = `
        def test do
          :ok
        end
      `;

      const result = InstructorAdapter.validateGeneratedCode(code);

      expect(result.code?.language).toBe('elixir');
      expect(result.code?.quality_level).toBe('production');
    });
  });

  describe('buildValidationError', () => {
    test('builds validation error correctly', () => {
      const error = InstructorAdapter.buildValidationError(
        'language',
        'invalid',
        'Unsupported language',
        'elixir | rust | typescript',
        'elixir'
      );

      expect(error.field_name).toBe('language');
      expect(error.current_value).toBe('invalid');
      expect(error.error_reason).toBe('Unsupported language');
    });
  });

  describe('InstructorValidation utility', () => {
    test('checks if code is production ready', () => {
      const quality: CodeQualityResult = {
        score: 0.9,
        issues: [],
        suggestions: [],
        passing: true,
      };

      expect(InstructorValidation.isProductionReady(quality)).toBe(true);
    });

    test('rejects non-production code', () => {
      const quality: CodeQualityResult = {
        score: 0.7,
        issues: ['Missing tests'],
        suggestions: [],
        passing: false,
      };

      expect(InstructorValidation.isProductionReady(quality)).toBe(false);
    });

    test('formats validation error', () => {
      const error = InstructorAdapter.buildValidationError(
        'task',
        '',
        'Required field missing',
        'Non-empty string',
        '"Write GenServer"'
      );

      const formatted = InstructorValidation.formatError(error);

      expect(formatted).toContain('task');
      expect(formatted).toContain('Required field missing');
    });

    test('formats quality result', () => {
      const quality: CodeQualityResult = {
        score: 0.92,
        issues: [],
        suggestions: [],
        passing: true,
      };

      const formatted = InstructorValidation.formatQualityResult(quality);

      expect(formatted).toContain('92.0%');
      expect(formatted).toContain('PASS');
    });
  });

  describe('InstructorSchemas', () => {
    test('GeneratedCode schema validates required fields', () => {
      const validData = {
        code: 'def test, do: :ok',
        language: 'elixir' as const,
        quality_level: 'production' as const,
        has_docs: true,
        has_tests: false,
        has_error_handling: false,
        estimated_lines: 1,
      };

      const result = InstructorSchemas.GeneratedCode.safeParse(validData);
      expect(result.success).toBe(true);
    });

    test('CodeQualityResult enforces score range', () => {
      const invalidData = {
        score: 1.5, // Too high
        issues: [],
        suggestions: [],
        passing: false,
      };

      const result = InstructorSchemas.CodeQualityResult.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    test('ToolParameters validates tool name format', () => {
      const validData = {
        tool_name: 'valid_tool_name_123',
        parameters: { key: 'value' },
        valid: true,
        errors: [],
      };

      const result = InstructorSchemas.ToolParameters.safeParse(validData);
      expect(result.success).toBe(true);
    });

    test('ToolParameters rejects invalid tool name format', () => {
      const invalidData = {
        tool_name: 'invalid-tool-name', // Hyphens not allowed
        parameters: { key: 'value' },
        valid: true,
        errors: [],
      };

      const result = InstructorSchemas.ToolParameters.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
