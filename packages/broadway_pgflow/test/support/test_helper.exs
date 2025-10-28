ExUnit.start()

# Mock setup for PGFlow and queue
Mox.defmock(Pgflow.WorkflowMock, for: Pgflow.Workflow.Behaviour)
Mox.defmock(QueueMock, for: Broadway.PgflowProducer.QueueBehaviour)

Application.put_env(:broadway_pgflow, :repo, Singularity.Repo)  # For tests, use test repo

# Configure Mox
Mox.configure(:test, [])