# Data Agent — build guide

Fabric **Data Agents** are created interactively in the workspace (no Git item
format yet), so this repo ships the agent as **config-as-code**:
`agent-config.yaml` (what to configure) + `instructions.md` (the system prompt).
Follow these steps to reproduce the agent.

## Prerequisites
- Gold Lakehouse `LH_Gold` populated (run the medallion notebooks).
- Certified semantic model `sm_customer360_gold` published to the workspace.
- Fabric capacity with **Data Agent** enabled (tenant admin setting).

## Steps

1. **Create the agent**
   - Workspace › **New** › **Data agent** (preview).
   - Name it **Customer Insights Agent** (from `agent-config.yaml › name`).

2. **Add data sources** (in the order listed in `agent-config.yaml › data_sources`)
   - Add the **`sm_customer360_gold`** semantic model (primary source).
   - Add the **`LH_Gold`** Lakehouse for row-level detail.

3. **Set agent instructions**
   - Paste the **## Instructions** section of `instructions.md` into the agent's
     main instructions box.

4. **Set per-source instructions**
   - For each source, paste the matching text from
     `agent-config.yaml › source_instructions`.

5. **Add example questions**
   - Add each item from `agent-config.yaml › example_queries` as a starter prompt.

6. **Test the guardrails**
   - Ask an out-of-scope question and confirm the agent declines / says it has no
     data, per `agent-config.yaml › guardrails`.

7. **Govern**
   - Apply the **Confidential** sensitivity label and restrict sharing.
   - Because the primary source is the certified model, the agent inherits its
     **RLS** — verify with **View as** on the model, then re-ask a scoped question.

## Keeping it in sync
Treat `agent-config.yaml` + `instructions.md` as the source of truth. When you
change measures or sources, update these files first, then re-apply in the UI.
