# Semantic model row-level security (RLS)

Two ways to enforce RLS for the demo. Prefer **one** consistent layer; the SQL
endpoint approach (`fabric/governance/rls-cls.sql`) governs *all* consumers,
while semantic-model RLS governs Power BI / Data Agent consumers of this model.

## Option A — Static role (simplest, great for a live demo)

In the semantic model, create a role and a table filter DAX expression.

Role **`US Only`** on table `customer_360`:

```DAX
[country] = "United States"
```

Assign a test user to the role, then **View as** that role in the model or report
to show the row set shrink. The Data Agent answers also respect the role.

## Option B — Dynamic RLS (per-user, production pattern)

Filter each user to the customers they own using the logged-in identity.

1. Add a mapping table `sec_account_owner_map(account_owner, user_principal_name)`
   to `LH_Gold` (one row per owner → the user's UPN).
2. Relate it to `customer_360[account_owner]`.
3. Role **`Account Owner`** filter on the mapping table:

```DAX
[user_principal_name] = USERPRINCIPALNAME()
```

Now every user sees only their own accounts, with no per-user role maintenance.

## Column-level security note

Power BI object-level security (OLS) can hide columns/measures per role (e.g. hide
`sensitivity_tier`). For the demo, the SQL-endpoint CLS in
`fabric/governance/rls-cls.sql` is the clearest illustration; OLS is the
semantic-model equivalent if you want it enforced in the model.

## Demo talking point

RLS/CLS defined **once** on the governed layer flows to **every** downstream
consumer — report visuals, Analyze in Excel, and the Data Agent — so security is
centralized, not re-implemented per report.
