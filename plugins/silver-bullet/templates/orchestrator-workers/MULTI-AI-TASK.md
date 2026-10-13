# Multi-AI task worker

Use this worker template for the `AF-MULTI-AI-TASK` atomic flow. The worker
receives a bounded task brief, selected model-pool configuration, and declared
artifact paths; it returns indexed results plus step-level evidence. Workers
must stay within the declared mutation scope and report unsupported hosts or
providers as an explicit routing decision.

## V-loop

1. Verify the task contract, pool manifest, and output root.
2. Dispatch only the selected lanes and record each result.
3. Reconcile outputs into the declared index and validate schema completeness.
4. Repair bounded failures once; escalate unresolved provider or artifact
   failures to the parent scheduler.
