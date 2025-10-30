ExUnit.start()

# Mock setup for QuantumFlow and queue
Mox.defmock(QuantumFlow.WorkflowMock, for: QuantumFlow.WorkflowAPI.Behaviour)
Mox.defmock(QueueMock, for: Broadway.QuantumFlowProducer.QueueBehaviour)

Application.put_env(:broadway_quantum_flow, :repo, Singularity.Repo)  # For tests, use test repo

# Configure Mox
Mox.configure(:test, [])