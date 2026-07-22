# Networking & the managed VNet data gateway (private SQL)

To satisfy org policy, both Azure SQL servers are created with **public network
access disabled** and are reachable only through **private endpoints** in a spoke
VNet. Fabric is a SaaS service on the public network, so it reaches the private
SQL endpoints through a **managed virtual network (VNet) data gateway** that
**Fabric provisions for you** into a subnet this template **delegates** to
`Microsoft.PowerPlatform/vnetaccesslinks`. There is **no VM or ACI** to deploy,
patch, or seed from — Fabric runs the gateway as a managed service.

> **Hub-spoke scope:** this template deploys **only the spoke** (VNet, subnets,
> private endpoints, private DNS, and the Fabric-delegated subnet). The **hub VNet
> and VNet peering are out of scope** — wire the spoke to your hub separately if
> outbound/hybrid routing must go through the hub.

## What the template deploys (networking RG)

| Resource | Purpose |
|---|---|
| `vnet-fabric-spoke` | Spoke VNet (`10.20.0.0/16` by default). |
| `snet-privatelink` (`10.20.1.0/24`) | Hosts the two SQL private endpoints. |
| `snet-fabric-gateway` (`10.20.2.0/24`) | **Delegated to `Microsoft.PowerPlatform/vnetaccesslinks`** so Fabric can inject its managed VNet data gateway. Left empty by the template. |
| `privatelink.database.windows.net` | Private DNS zone, linked to the spoke, so `*.database.windows.net` resolves to the private-endpoint IPs from inside the VNet (the managed gateway lives in the spoke). |
| `pe-sql-ops`, `pe-sql-etl` | Private endpoints for the two SQL servers. |

The template also sets the **deploying user** as the **Microsoft Entra admin** on
both SQL servers, so you can seed them from Fabric with your own account.

## Step 1 — Create the managed VNet data gateway in Fabric (MANUAL)

Prerequisites: a Fabric (or Power BI Premium/PPU) capacity, and the tenant setting
**Azure connections → Virtual network data gateways** enabled by your admin.

1. In the Fabric/Power BI portal, go to **Settings → Manage connections and
   gateways → Virtual network data gateways → New**.
2. Fill in:
   - **Subscription:** the subscription you deployed into.
   - **Resource group:** the **networking RG** (`networkResourceGroupName`,
     default `rg-fabric-e2e-network`).
   - **Virtual network:** `vnetName` (default `vnet-fabric-spoke`).
   - **Subnet:** the delegated subnet `fabricGatewaySubnetName`
     (default `snet-fabric-gateway`). It must be the delegated subnet — the
     template already delegated it for you.
3. Give the gateway a name and create it. Fabric injects the managed gateway into
   that subnet. Because the subnet is in the spoke VNet and the private DNS zone is
   linked, the gateway resolves `*.database.windows.net` to the private-endpoint
   IPs automatically — no hosts-file edits, no VM.

> Put the VNet/gateway in the **same region** as your Fabric capacity where
> possible for best latency.

## Step 2 — Create connections to the private SQL servers

For **each** SQL server (ops and etl), create a connection that uses the gateway:

1. **Manage connections and gateways → Connections → New**, or create it inline the
   first time you configure Mirroring / a Copy Job.
2. Set:
   - **Connection type:** SQL Server.
   - **Server:** `<opsSqlServerFqdn>` or `<etlSqlServerFqdn>` (from the deployment
     outputs / `infra\deployment-outputs.json`).
   - **Database:** `sqldb-ops` or `sqldb-etl`.
   - **Data gateway:** the **virtual network data gateway** you created in Step 1.
   - **Authentication:** **Organizational account** — sign in with the account that
     was set as the SQL Entra admin (`sqlEntraAdminLogin` in the outputs, i.e. the
     account you deployed with).

## Step 3 — Seed the databases from Fabric

The databases are empty after deployment (no in-VNet compute exists to seed them).
Seed them **through the gateway** with your admin account:

1. In your Fabric workspace, create a **Data pipeline**.
2. Add a **Script** activity, set its **Connection** to the **sqldb-ops** connection
   from Step 2, and paste the contents of
   [`../data/sql/ops_seed.sql`](../data/sql/ops_seed.sql) as the script (it creates
   `customers` and `products` and inserts the demo rows).
3. Add a second **Script** activity on the **sqldb-etl** connection with the
   contents of [`../data/sql/etl_seed.sql`](../data/sql/etl_seed.sql) (creates
   `orders` and `support_tickets`).
4. **Run** the pipeline. Both databases are now seeded over the private endpoints.
5. **Delete the seed pipeline** once both databases are loaded — see the note below.

> ### ⚠️ Keep the seed pipeline OUT of Git
>
> A Data pipeline **is a Git-tracked item type**, so after you create it, it appears
> in the workspace **Source control** pane as an *uncommitted* change. It is a
> one-time, environment-specific bootstrap (it references *your* gateway
> connections) and must **not** land in the repo, or future deployments would sync a
> stray, broken artifact.
>
> Fabric never pushes to Git automatically — nothing reaches the repo until you
> click **Commit**. So the rule is simple:
>
> - **Never commit the seed pipeline**, and
> - **Delete it after seeding** so the Source control pane stays clean and it can't
>   be swept into a later "commit all."
>
> **Same workspace vs. a separate one:** the same end-to-end workspace is the
> simplest choice — the gateway, connections, and target Lakehouses are all here,
> and the *don't-commit-then-delete* rule keeps the repo clean. If you'd rather keep
> this workspace's Source control pane pristine, create the seed pipeline in a
> **separate, non–Git-connected "bootstrap" workspace** instead; connections and
> gateways are **tenant-level** (*Manage connections and gateways*), so they work
> from any workspace.

> Alternatives to a pipeline: run the same `.sql` files from any host that already
> has private line-of-sight to the servers (e.g. a jump host in a peered hub, or
> Azure Cloud Shell configured with VNet access). The Fabric pipeline path needs no
> extra infrastructure and is the recommended approach for this demo.

The Shortcut reference file in blob storage is uploaded separately by
`scripts\Deploy-Azure.ps1` / `scripts\Seed-Data.ps1` (storage is public, so that
runs from your laptop).

## Step 4 — Use the gateway from Fabric ingestion

When you configure **Mirroring** and the **Copy Job** (see
[`ingestion-mirroring.md`](ingestion-mirroring.md) and
[`ingestion-etl-copyjob.md`](ingestion-etl-copyjob.md)), pick the connections from
Step 2 (which already use the managed VNet gateway).

> **Mirroring note:** Fabric Mirroring for Azure SQL must reach the source over a
> network path it supports. The managed **virtual network data gateway** is the
> supported private-connectivity option for Azure SQL Database sources; make sure
> the tenant setting is enabled and the connection above uses it. If Mirroring
> reports it cannot use the connection, fall back to the **Copy Job / Dataflow**
> pattern (which fully supports the VNet gateway) for that source, or open the
> source to a supported private path per current Fabric docs.

## Troubleshooting

- **Gateway won't create / subnet not selectable:** confirm the subnet is delegated
  to `Microsoft.PowerPlatform/vnetaccesslinks` (it is, in `snet-fabric-gateway`) and
  that no other resource occupies it. Confirm the tenant setting *Virtual network
  data gateways* is enabled.
- **Connection can't resolve/reach SQL:** confirm the private DNS zone
  `privatelink.database.windows.net` is linked to the spoke VNet and that each
  private endpoint's DNS zone group applied (a record per server should exist in
  the zone). From a peered host, `nslookup <opsSqlServerFqdn>` should return a
  `10.20.1.x` address.
- **Login fails when seeding:** ensure you are signing in as the SQL Entra admin
  (`sqlEntraAdminLogin` output). To add more admins/users, connect as the admin and
  run `CREATE USER [...] FROM EXTERNAL PROVIDER;` + role grants.
