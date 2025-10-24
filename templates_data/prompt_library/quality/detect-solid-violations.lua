-- Code Quality Pattern Detection: SOLID Violations
-- Detects SOLID principle violations
--
-- Version: 1.0.0
-- Used by: Centralcloud.ArchitectureLLMTeam (Pattern Validator agent)
-- Model: GPT-4 Turbo (excellent at technical validation)
--
-- SOLID Principles:
-- S - Single Responsibility Principle
-- O - Open/Closed Principle
-- L - Liskov Substitution Principle
-- I - Interface Segregation Principle
-- D - Dependency Inversion Principle
--
-- Input variables:
--   code_samples: table - Array of {path, content, language}
--   check_principles: table - Which principles to check (default: all)
--
-- Returns: Lua prompt string for LLM

local Prompt = require("prompt")
local prompt = Prompt.new()

-- Extract input
local code_samples = variables.code_samples or {}
local check_principles = variables.check_principles or {"S", "O", "L", "I", "D"}
local max_methods_per_class = variables.max_methods_per_class or 10
local max_lines_per_method = variables.max_lines_per_method or 50

prompt:add("# Code Quality Pattern Detection: SOLID Violations")
prompt:add("")

prompt:section("ROLE", [[
You are the Pattern Validator on the Architecture LLM Team.
Your specialty is validating technical correctness and design principles.
Focus: Detecting SOLID principle violations in code.
]])

local principles_to_check = table.concat(check_principles, ", ")

prompt:section("TASK", string.format([[
Analyze this code and detect SOLID principle violations.

Check these principles: %s

SOLID Definitions:

S - Single Responsibility Principle (SRP)
    "A class should have only ONE reason to change"
    Violations:
    - God classes (too many methods: > %d)
    - Long methods (> %d lines)
    - Mixed concerns (UI + business logic + data access)

O - Open/Closed Principle (OCP)
    "Open for extension, closed for modification"
    Violations:
    - Long if/else or case chains on types
    - Not using polymorphism/protocols
    - Hardcoded type checking

L - Liskov Substitution Principle (LSP)
    "Subtypes must be substitutable for base types"
    Violations:
    - Subclass changes expected behavior
    - Throws exceptions base class doesn't throw
    - Requires more, promises less

I - Interface Segregation Principle (ISP)
    "Many specific interfaces better than one general"
    Violations:
    - Fat interfaces (too many methods)
    - Clients forced to depend on unused methods
    - Interface contains unrelated methods

D - Dependency Inversion Principle (DIP)
    "Depend on abstractions, not concretions"
    Violations:
    - Direct instantiation of concrete classes
    - Not using dependency injection
    - Tight coupling to specific implementations
]], principles_to_check, max_methods_per_class, max_lines_per_method))

-- Add code samples
for i, sample in ipairs(code_samples) do
  prompt:section(string.format("CODE_SAMPLE_%d", i), string.format([[
File: %s
Language: %s

Content:
```%s
%s
```
]], sample.path, sample.language, sample.language, sample.content))
end

prompt:section("DETECTION_GUIDELINES", string.format([[
For each violation:
1. Identify which SOLID principle is violated (S, O, L, I, or D)
2. Explain why it's a violation
3. Show specific code that violates
4. Suggest refactoring to fix

Be specific - don't just say "violates SRP", explain:
- What are the multiple responsibilities?
- What should be separated?
- How to refactor?

Thresholds:
- Max methods per class: %d (SRP)
- Max lines per method: %d (SRP)
]], max_methods_per_class, max_lines_per_method))

prompt:section("OUTPUT_FORMAT", [[
Return ONLY valid JSON in this exact format:

{
  "solid_violations": [
    {
      "violation_id": 1,
      "principle": "S",
      "principle_name": "Single Responsibility",
      "severity": "error",
      "location": {
        "file": "lib/user_controller.ex",
        "module": "UserController",
        "start_line": 1,
        "end_line": 150
      },
      "description": "UserController has multiple responsibilities: HTTP handling, business logic, email sending, and logging",
      "evidence": {
        "method_count": 15,
        "responsibilities": [
          "HTTP request/response handling",
          "User validation logic",
          "Email notification sending",
          "Audit logging",
          "Error formatting"
        ],
        "code_snippet": "defmodule UserController do\n  # 15 methods mixing concerns\n  def create(conn, params) do\n    # Validates\n    # Sends email\n    # Logs\n    # Returns HTTP\n  end\nend"
      },
      "refactoring_suggestion": {
        "approach": "extract_service_objects",
        "details": "Separate into: UserController (HTTP), UserService (business logic), EmailService (notifications), AuditLogger (logging)",
        "code_example": "defmodule UserController do\n  def create(conn, params) do\n    case UserService.create(params) do\n      {:ok, user} -> json(conn, user)\n      {:error, changeset} -> json(conn, changeset)\n    end\n  end\nend\n\ndefmodule UserService do\n  def create(params) do\n    # Business logic only\n  end\nend"
      },
      "impact": {
        "maintainability": "high",
        "testability": "high",
        "reasoning": "Changes to email logic require modifying controller, mixing concerns makes testing difficult"
      }
    },
    {
      "violation_id": 2,
      "principle": "O",
      "principle_name": "Open/Closed",
      "severity": "warn",
      "location": {
        "file": "lib/notification_sender.ex",
        "function": "send_notification/2",
        "start_line": 10,
        "end_line": 30
      },
      "description": "Type switching on notification type - must modify function to add new types",
      "evidence": {
        "code_snippet": "def send_notification(user, type) do\n  case type do\n    :email -> send_email(user)\n    :sms -> send_sms(user)\n    :push -> send_push(user)\n    # Must add new case for new type!\n  end\nend"
      },
      "refactoring_suggestion": {
        "approach": "use_protocols",
        "details": "Use Elixir protocols for polymorphic behavior",
        "code_example": "defprotocol NotificationSender do\n  def send(notification, user)\nend\n\ndefimpl NotificationSender, for: EmailNotification do\n  def send(_, user), do: send_email(user)\nend\n\ndefimpl NotificationSender, for: SmsNotification do\n  def send(_, user), do: send_sms(user)\nend\n\n# Now can add new types without modifying existing code!"
      }
    },
    {
      "violation_id": 3,
      "principle": "D",
      "principle_name": "Dependency Inversion",
      "severity": "warn",
      "location": {
        "file": "lib/order_service.ex",
        "function": "create_order/1",
        "start_line": 5,
        "end_line": 15
      },
      "description": "Direct dependency on concrete PayPalGateway - should depend on abstraction",
      "evidence": {
        "code_snippet": "def create_order(params) do\n  gateway = PayPalGateway.new()  # Hardcoded!\n  gateway.charge(params.amount)\nend"
      },
      "refactoring_suggestion": {
        "approach": "dependency_injection",
        "details": "Inject payment gateway as dependency (protocol/behavior)",
        "code_example": "defmodule OrderService do\n  def create_order(params, gateway \\\\ PaymentGateway.default()) do\n    gateway.charge(params.amount)\n  end\nend\n\n# Can now inject test double or swap PayPal for Stripe!"
      }
    }
  ],
  "summary": {
    "total_violations": 3,
    "by_principle": {
      "S": 1,
      "O": 1,
      "L": 0,
      "I": 0,
      "D": 1
    },
    "by_severity": {
      "error": 1,
      "warn": 2,
      "info": 0
    },
    "overall_solid_score": 70,
    "files_affected": 3
  },
  "good_practices_found": [
    {
      "file": "lib/user.ex",
      "principle": "S",
      "description": "User module has single responsibility (data structure)",
      "code_snippet": "defmodule User do\n  # Only defines user data, no business logic\n  schema \"users\" do\n    field :name, :string\n  end\nend"
    }
  ],
  "recommendations": [
    "Extract business logic from controllers (SRP)",
    "Use protocols instead of type switching (OCP)",
    "Inject dependencies instead of hardcoding (DIP)",
    "Consider using behavior/protocol for abstractions"
  ],
  "quality_assessment": {
    "solid_adherence": "moderate",
    "improvement_potential": "high",
    "priority": "medium",
    "estimated_effort": "4-8 hours to refactor violations"
  },
  "llm_reasoning": "Found 3 SOLID violations. Most critical is SRP violation in UserController (mixing 5 responsibilities). Also found OCP violation (type switching) and DIP violation (hardcoded dependency). Overall SOLID score: 70/100 (needs improvement in S, O, D principles)."
}

Do NOT include markdown code fences or explanations.
Just raw JSON.
]])

return prompt:render()
