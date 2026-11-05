# AIRBNB Data Warehouse (dbt + Snowflake)

An analytics engineering project that transforms raw Airbnb-style booking, host and listing data into a layered warehouse on **Snowflake**, built with **dbt** (data build tool). Raw data lands in a `staging` schema and is progressively refined through **bronze → silver → gold** layers, ending in a one-big-table (OBT) model, star-schema-style dimensions and a fact model, with data quality tests and slowly changing dimension snapshots.

## Architecture

```
AIRBNB.staging  (raw source tables: bookings, hosts, listings)
      │
      ▼
 bronze  (incremental copies of the raw tables, filtered on CREATED_AT)
      │
      ▼
 silver  (cleaned & enriched, merged on business keys)
      │
      ▼
 gold
   ├── obt                 one big table: bookings ⋈ listings ⋈ hosts
   ├── ephemeral views     bookings / hosts / listings slices of obt & silver
   ├── dim_* snapshots     SCD Type 2 history for bookings, hosts, listings
   └── fact                fact table joined to the OBT and dimensions
```

## Project structure

```
.
├── pyproject.toml              Python project metadata and dependencies (dbt-core, dbt-snowflake)
├── uv.lock                     Locked dependency versions (managed by uv)
├── .python-version             Python 3.12
├── src/aws_dbt_snowflake/      Placeholder Python package (entry point stub)
└── aws_dbt_snowflake_project/  The dbt project
    ├── dbt_project.yml         Project config: layer materializations and schemas
    ├── models/
    │   ├── sources/            Source definitions for AIRBNB.staging
    │   ├── bronze/             Incremental raw copies of the source tables
    │   ├── silver/             Cleaned and transformed tables
    │   └── gold/               OBT, fact, and ephemeral helper models
    ├── snapshots/              SCD Type 2 snapshots (dim_bookings, dim_hosts, dim_listings)
    ├── macros/                 Reusable Jinja macros (multiply, tag, trimmer, generate_schema_name)
    ├── tests/                  Generic (schema.yml-style) and singular SQL data tests
    └── analyses/               Ad-hoc SQL analyses (not built by dbt run)
```

## Layers in detail

### Bronze (`models/bronze/`)
- `bronze_bookings`, `bronze_hosts`, `bronze_listings` select everything from the `AIRBNB.staging` source tables.
- Materialized as **incremental**: on subsequent runs only rows with `CREATED_AT` later than the current maximum are loaded.

### Silver (`models/silver/`)
- `silver_bookings`: keyed on `booking_id`; computes `total_price = round(nights_booked * booking_amount, 2)` via the `multiply` macro.
- `silver_listings`: keyed on `listing_id`; adds `price_category` (`low` < 100, `medium` 100–199, `high` ≥ 200) via the `tag` macro.
- `silver_hosts`: keyed on `host_id`; normalizes `host_name` (trimmed, spaces replaced with underscores) and buckets `response_rate` into `low` / `average` / `high`.
- All silver models are **incremental with a `unique_key`**, so reruns upsert instead of duplicating rows.

### Gold (`models/gold/`)
- `obt`: the one-big-table model. Joins `silver_bookings` → `silver_listings` → `silver_hosts` into a single wide table for analytics.
- `ephemeral/` (`bookings`, `hosts`, `listings`): lightweight ephemeral CTEs that expose subsets of `obt` / silver columns. They are compiled inline and never materialized as objects in the warehouse.
- `fact`: builds the fact table from `AIRBNB.GOLD.OBT`, left-joined to `DIM_LISTINGS` and `DIM_HOSTS`, with the measures (`TOTAL_PRICE`, `SERVICE_FEE`, `CLEANING_FEE`) and keys.

### Snapshots (`snapshots/`)
- `dim_bookings`, `dim_hosts`, `dim_listings` track history using the `timestamp` strategy, written to the `GOLD` schema, so changes to source records are kept with validity windows (`dbt_valid_from` / `dbt_valid_to`).

### Macros (`macros/`)
| Macro | Purpose |
|---|---|
| `multiply(x, y, precision)` | Rounded product, e.g. for `total_price` |
| `tag(col)` | Buckets a numeric column into `low` / `medium` / `high` |
| `trimmer(col, node)` | Trims and upper-cases a string column |
| `generate_schema_name` | Overrides dbt's default so custom schemas (`bronze`, `silver`, `gold`) are used as-is |

### Tests (`tests/`)
- **Generic tests** (`generic_test.yml`): `unique` and `not_null` on the primary keys of `silver_bookings`, `silver_listings` and `silver_hosts`.
- **Singular test** (`singular_test.sql`, severity `warn`): checks that `total_price` is never negative and that `nights_booked` is at least 1.

## Prerequisites

- Python **3.12+**
- [uv](https://docs.astral.sh/uv/) (recommended) or pip
- A **Snowflake** account with:
  - a database named `AIRBNB` containing a `staging` schema with the `bookings`, `hosts` and `listings` tables
  - a role and warehouse with rights to create schemas and tables
- The `CREATED_AT` column present on all three source tables

## Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/vinayshetty777/AIRBNB_DATA_WAREHOUSE.git
   cd AIRBNB_DATA_WAREHOUSE
   ```

2. **Install dependencies**
   ```bash
   uv sync
   ```
   This creates `.venv` and installs `dbt-core` and `dbt-snowflake` from `uv.lock`.

3. **Configure the Snowflake connection.** The `profiles.yml` file is git-ignored, so create it yourself at `~/.dbt/profiles.yml`. The profile name must match `profile:` in `dbt_project.yml`, which is `aws_dbt_snowflake_project`:
   ```yaml
   aws_dbt_snowflake_project:
     target: dev
     outputs:
       dev:
         type: snowflake
         account: <your_account_identifier>
         user: <your_user>
         password: <your_password>      # or use key-pair / SSO auth
         role: <your_role>
         database: AIRBNB
         warehouse: <your_warehouse>
         schema: <default_schema>
         threads: 4
   ```
   Keep credentials out of version control.

4. **Check the connection**
   ```bash
   cd aws_dbt_snowflake_project
   uv run dbt debug
   ```

## Running the pipeline

Run these from inside `aws_dbt_snowflake_project/`:

```bash
uv run dbt run        # build bronze, silver and gold models
uv run dbt snapshot   # capture SCD Type 2 history for the dim_* snapshots
uv run dbt test       # run generic and singular data quality tests
uv run dbt build      # run, test and snapshot in dependency order
```

Useful options:
- `uv run dbt run --select silver` builds only the silver layer.
- `uv run dbt run --select +obt` builds `obt` and everything it depends on.
- `uv run dbt docs generate && uv run dbt docs serve` produces and serves the documentation site and lineage graph.

## Tech stack

- **Data warehouse:** Snowflake
- **Transformation:** dbt Core, dbt-snowflake adapter (`>= 1.12`)
- **Language and tooling:** Python 3.12, uv
- **Modeling patterns:** medallion architecture (bronze / silver / gold), incremental models, ephemeral models, SCD Type 2 snapshots, OBT and star-schema-style facts and dimensions

## Notes

- `src/aws_dbt_snowflake/__init__.py` is a placeholder entry point and does not affect the dbt pipeline.
- `analyses/sammple.sql` is a scratch query and is not part of the build.
- The `dim_*` snapshots and the `fact` model read from the `AIRBNB.GOLD` schema. Run `dbt snapshot` at least once before building `fact`.
