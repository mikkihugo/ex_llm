////
//// OTP Supervisor for Rule Execution Workers
////
//// Uses Gleam OTP to supervise rule execution processes.
//// Each rule execution runs in isolated process with correlation tracking.
////

import gleam/otp/supervisor
import gleam/otp/actor
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import singularity/rule_engine.{type Rule, type Context, type RuleResult}

pub type Message {
  Execute(rule: Rule, context: Context, correlation_id: String, reply: Subject(RuleResult))
  Shutdown
}

pub type State {
  State(
    correlation_id: String,
    executions_count: Int,
  )
}

/// Start supervised rule executor
pub fn start_link() {
  supervisor.start_link(fn(children) {
    children
    |> supervisor.add(supervisor.worker(start_worker))
    |> supervisor.returning(fn(_children, _builder) { supervisor.Ready })
  })
}

/// Start individual worker process
fn start_worker() {
  actor.start_spec(actor.Spec(
    init: fn() {
      let state = State(correlation_id: "", executions_count: 0)
      actor.Ready(state, process.new_selector())
    },
    init_timeout: 1000,
    loop: handle_message,
  ))
}

fn handle_message(message: Message, state: State) -> actor.Next(Message, State) {
  case message {
    Execute(rule, context, correlation_id, reply) -> {
      // Set correlation in process dictionary (OTP pattern)
      set_correlation(correlation_id)

      // Execute rule
      let result = rule_engine.execute_rule(rule, context)

      // Reply to caller
      process.send(reply, result)

      // Update state
      let new_state = State(
        correlation_id: correlation_id,
        executions_count: state.executions_count + 1
      )

      actor.continue(new_state)
    }

    Shutdown -> {
      actor.Stop(process.Normal)
    }
  }
}

/// Set correlation ID in process dictionary
@external(erlang, "erlang", "put")
fn set_correlation(key: atom, value: String) -> Option(String)

fn set_correlation(correlation_id: String) -> Option(String) {
  // Process dictionary in Erlang: put(:correlation_id, value)
  set_correlation(correlation_id_atom(), correlation_id)
}

@external(erlang, "erlang", "atom")
fn correlation_id_atom() -> atom
