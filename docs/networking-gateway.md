# Networking & the VNet data gateway (private SQL)

To satisfy org policy, both Azure SQL servers are created with **public network
access disabled** and are reachable only through **private endpoints** in a spoke
VNet. Fabric is a SaaS service on the public network, so it reaches the private
SQL endpoints through an **on-premises data gateway** installed on a Windows VM
inside the spoke VNet (a "VNet data gateway" pattern).

> **Hub-spoke scope:** this template deploys **only the spoke** (VNet, subnets,
> private endpoints, private DNS, gateway VM). The **hub VNet and VNet peering are
> out of scope** — wire the spoke to your hub separately if outbound/hybrid routing
> must go through the hub. The gateway VM has a public IP for RDP + outbound so the
> demo works without a hub.

## What the template deploys (networking RG)

| Resource | Purpose |
|---|---|
| `vnet-fabric-spoke` | Spoke VNet (`10.20.0.0/16` by default). |
| `snet-privatelink` (`10.20.1.0/24`) | Hosts the two SQL private endpoints. |
| `snet-gateway` (`10.20.2.0/24`) | Hosts the gateway VM. |
| `privatelink.database.windows.net` | Private DNS zone, linked to the spoke, so `*.database.windows.net` resolves to the private-endpoint IPs from inside the VNet. |
| `pe-sql-ops`, `pe-sql-etl` | Private endpoints for the two SQL servers. |
| `vm-fabric-gw` (+ NIC, NSG, public IP) | Windows Server VM for the data gateway; also runs the seed. |

## Step 1 — Seed runs automatically (from the VM)

When `seedData = true` (default), the VM's Custom Script Extension runs
[`../scripts/vm-seed.ps1`](../scripts/vm-seed.ps1): it authenticates as the
user-assigned managed identity (the SQL Entra admin), seeds both databases over
the private endpoints, grants you `db_owner`, and uploads the Shortcut file. Check
progress by RDP'ing to the VM and opening `C:\seed-log.txt`. The extension always
exits 0, so a seeding hiccup never fails the deployment — re-run it if needed.

## Step 2 — Install the on-premises data gateway (MANUAL)

1. **RDP to the gateway VM.** Use the public IP from the deployment outputs
   (`gatewayVmPublicIp`) and the admin username (`vmAdminUsername`, default
   `fabricadmin`). The password has a generated default — reset it in the portal
   (**VM → Reset password**) if you did not pass your own `vmAdminPassword`.
   > RDP is only allowed from the `clientIpAddress` you passed (NSG rule). If you
   > left it empty, add an inbound 3389 rule from your IP, or use Azure Bastion.
2. **Download & install** the standard **on-premises data gateway** (standard mode,
   not personal) from https://aka.ms/OnPremisesDataGateway. Run the installer on
   the VM.
3. **Sign in** with your Microsoft Entra (work) account and **register a new
   gateway** (give it a name, set a recovery key). This creates a gateway cluster
   in Power BI / Fabric.
4. Because the VM is inside the spoke VNet and the private DNS zone is linked, the
   gateway resolves `*.database.windows.net` to the private endpoint IPs
   automatically — no hosts-file edits needed.

## Step 3 — Use the gateway from Fabric

1. In the Fabric/Power BI portal, the registered gateway appears under
   **Settings → Manage connections and gateways → On-premises data gateways**.
2. When you create the **Mirroring** / **Copy Job** connection (see
   [`ingestion-mirroring.md`](ingestion-mirroring.md) and
   [`ingestion-etl-copyjob.md`](ingestion-etl-copyjob.md)), choose this gateway as
   the **data gateway** for the connection, server =
   `<opsSqlServerFqdn>` / `<etlSqlServerFqdn>`, and authenticate with your
   **Organizational account** (the account granted `db_owner`).

## Alternative: managed VNet data gateway

Instead of a VM, Fabric also supports a fully **managed virtual network data
gateway** (no VM to patch), which delegates a subnet to
`Microsoft.PowerPlatform/vnetaccesslinks`. It requires a supported Fabric/Power BI
capacity and tenant settings. This template uses the VM approach because it works
on any capacity and keeps the demo self-contained; switching to the managed
gateway is a valid hardening step for production.

## Troubleshooting

- **Seeding didn't happen:** RDP to the VM, read `C:\seed-log.txt`. Re-run by
  redeploying (the `seedForceUpdateTag` changes each deploy) or run
  `scripts\vm-seed.ps1` on the VM.
- **Gateway can't reach SQL:** confirm on the VM that
  `nslookup <opsSqlServerFqdn>` returns a `10.20.1.x` (private) address. If it
  returns a public IP, the private DNS zone link or the private endpoint DNS zone
  group didn't apply.
- **Fabric connection fails with the gateway:** ensure the gateway is **online**
  in *Manage connections and gateways* and that your account has `db_owner`.
