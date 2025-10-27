defmodule Singularity.Execution.TodoStoreTest do
  use Singularity.DataCase, async: true

  alias Singularity.Execution.{TodoStore, Todo}

  describe "create/1" do
    test "creates a todo with valid attributes" do
      attrs = %{
        title: "Implement authentication",
        description: "Add JWT-based authentication",
        priority: 2,
        complexity: "medium",
        tags: ["backend", "security"]
      }

      assert {:ok, %Todo{} = todo} = TodoStore.create(attrs)
      assert todo.title == "Implement authentication"
      assert todo.description == "Add JWT-based authentication"
      assert todo.priority == 2
      assert todo.complexity == "medium"
      assert todo.status == "pending"
      assert todo.tags == ["backend", "security"]
    end

    test "requires title" do
      attrs = %{description: "Test description"}

      assert {:error, %Ecto.Changeset{} = changeset} = TodoStore.create(attrs)
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates priority range" do
      attrs = %{title: "Test", priority: 10}

      assert {:error, %Ecto.Changeset{} = changeset} = TodoStore.create(attrs)
      assert %{priority: ["is invalid"]} = errors_on(changeset)
    end

    test "validates complexity enum" do
      attrs = %{title: "Test", complexity: "invalid"}

      assert {:error, %Ecto.Changeset{} = changeset} = TodoStore.create(attrs)
      assert %{complexity: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "get/1" do
    test "retrieves an existing todo" do
      {:ok, todo} = TodoStore.create(%{title: "Test todo"})

      assert {:ok, retrieved_todo} = TodoStore.get(todo.id)
      assert retrieved_todo.id == todo.id
      assert retrieved_todo.title == "Test todo"
    end

    test "returns error for non-existent todo" do
      assert {:error, :not_found} = TodoStore.get(Ecto.UUID.generate())
    end
  end

  describe "list/1" do
    test "lists all todos" do
      {:ok, _todo1} = TodoStore.create(%{title: "Todo 1", priority: 1})
      {:ok, _todo2} = TodoStore.create(%{title: "Todo 2", priority: 2})

      todos = TodoStore.list()
      assert length(todos) >= 2
    end

    test "filters by status" do
      {:ok, todo} = TodoStore.create(%{title: "Test todo"})
      {:ok, _completed} = TodoStore.complete(todo, %{result: "done"})

      pending_todos = TodoStore.list(status: "pending")
      completed_todos = TodoStore.list(status: "completed")

      assert Enum.all?(pending_todos, &(&1.status == "pending"))
      assert Enum.all?(completed_todos, &(&1.status == "completed"))
    end

    test "filters by priority" do
      {:ok, _todo1} = TodoStore.create(%{title: "High priority", priority: 1})
      {:ok, _todo2} = TodoStore.create(%{title: "Low priority", priority: 4})

      high_priority = TodoStore.list(priority: 1)
      assert Enum.all?(high_priority, &(&1.priority == 1))
    end

    test "limits results" do
      for i <- 1..5 do
        TodoStore.create(%{title: "Todo #{i}"})
      end

      todos = TodoStore.list(limit: 2)
      assert length(todos) == 2
    end
  end

  describe "status management" do
    setup do
      {:ok, todo} = TodoStore.create(%{title: "Test todo"})
      %{todo: todo}
    end

    test "assigns todo to agent", %{todo: todo} do
      assert {:ok, updated} = TodoStore.assign(todo, "agent-123")
      assert updated.status == "assigned"
      assert updated.assigned_agent_id == "agent-123"
    end

    test "starts todo", %{todo: todo} do
      assert {:ok, updated} = TodoStore.start(todo)
      assert updated.status == "in_progress"
      assert updated.started_at != nil
    end

    test "completes todo", %{todo: todo} do
      {:ok, started} = TodoStore.start(todo)
      result = %{output: "Task completed successfully"}

      assert {:ok, completed} = TodoStore.complete(started, result)
      assert completed.status == "completed"
      assert completed.result == result
      assert completed.completed_at != nil
    end

    test "fails todo and retries if under max_retries", %{todo: todo} do
      {:ok, started} = TodoStore.start(todo)

      assert {:ok, failed} = TodoStore.fail(started, "Error occurred")
      # Auto-retried
      assert failed.status == "pending"
      assert failed.retry_count == 1
      assert failed.error_message == "Error occurred"
    end

    test "fails todo permanently when max_retries reached" do
      {:ok, todo} = TodoStore.create(%{title: "Test", max_retries: 1})
      {:ok, started} = TodoStore.start(todo)
      {:ok, failed1} = TodoStore.fail(started, "First failure")

      # Second failure should not retry
      {:ok, started2} = TodoStore.start(failed1)
      {:ok, failed2} = TodoStore.fail(started2, "Second failure")

      assert failed2.status == "failed"
      assert failed2.retry_count == 2
    end
  end

  describe "dependencies_satisfied?/1" do
    test "returns true when no dependencies" do
      {:ok, todo} = TodoStore.create(%{title: "Test"})
      assert TodoStore.dependencies_satisfied?(todo)
    end

    test "returns false when dependencies not completed" do
      {:ok, dep1} = TodoStore.create(%{title: "Dependency 1"})
      {:ok, todo} = TodoStore.create(%{title: "Test", depends_on_ids: [dep1.id]})

      refute TodoStore.dependencies_satisfied?(todo)
    end

    test "returns true when all dependencies completed" do
      {:ok, dep1} = TodoStore.create(%{title: "Dependency 1"})
      {:ok, started} = TodoStore.start(dep1)
      {:ok, _completed} = TodoStore.complete(started, %{result: "done"})

      {:ok, todo} = TodoStore.create(%{title: "Test", depends_on_ids: [dep1.id]})

      assert TodoStore.dependencies_satisfied?(todo)
    end
  end

  describe "get_next_available/1" do
    test "returns highest priority todo without dependencies" do
      {:ok, _low} = TodoStore.create(%{title: "Low priority", priority: 5})
      {:ok, high} = TodoStore.create(%{title: "High priority", priority: 1})

      assert {:ok, next} = TodoStore.get_next_available()
      assert next.id == high.id
    end

    test "skips todos with unsatisfied dependencies" do
      {:ok, dep} = TodoStore.create(%{title: "Dependency", priority: 1})

      {:ok, _blocked} =
        TodoStore.create(%{title: "Blocked", priority: 1, depends_on_ids: [dep.id]})

      {:ok, available} = TodoStore.create(%{title: "Available", priority: 2})

      assert {:ok, next} = TodoStore.get_next_available()
      assert next.id == dep.id || next.id == available.id
      refute next.title == "Blocked"
    end

    test "returns error when no todos available" do
      assert {:error, :no_available_todos} = TodoStore.get_next_available()
    end
  end

  describe "get_stats/0" do
    test "returns todo statistics" do
      {:ok, _pending} = TodoStore.create(%{title: "Pending", priority: 1})
      {:ok, completed_todo} = TodoStore.create(%{title: "Completed", priority: 2})
      {:ok, started} = TodoStore.start(completed_todo)
      {:ok, _} = TodoStore.complete(started, %{result: "done"})

      stats = TodoStore.get_stats()

      assert stats.total >= 2
      assert stats.by_status.pending >= 1
      assert stats.by_status.completed >= 1
      assert stats.by_priority.critical >= 1
      assert stats.by_priority.high >= 1
    end
  end
end
