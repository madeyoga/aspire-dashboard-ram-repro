# Aspire dashboard memory reproduction

Memory footprint of the **standalone Aspire dashboard** vs **`aspire dashboard run`** on Linux x64 (Aspire 13.6.0).

Context: ephemeral cloud development environments where every MB of RAM counts. Related discussion: [microsoft/aspire#20740](https://github.com/microsoft/aspire/issues/20740).

## Environment

- Linux x64, 8 cores, 16 GB RAM
- Aspire **13.6.0**
- Memory: RSS from `/proc/<pid>/status` (`VmRSS`), PSS from `/proc/<pid>/smaps_rollup`
- Idle sample taken 20 s after the UI responded
- Load: synthetic OTLP spans (10 spans per trace) via HTTP `:4318` and gRPC `:4317`

Numbers below are from a **single run**.

## Results

| Artifact / setup | On disk | RAM |
|---|---|---|
| `Aspire.Cli` 13.6.0 (pointer nupkg) | 39,478 B nupkg; 57 KB unpacked (`DotnetToolSettings.xml` only, points at RID packages) | — |
| `Aspire.Cli.linux-x64` 13.6.0 | 157.8 MB nupkg; **192 MB** native binary | CLI process alone **~240 MB RSS** (229 MB PSS), flat under load |
| `Aspire.Dashboard.Sdk.linux-x64` 13.6.0 | 37.8 MB nupkg; **92 MB** unpacked (79 MB native binary) | **136 MB RSS / 129 MB PSS** idle → 144 MB after 1,000 spans → **163 MB RSS (154 MB PSS)** after 11,000 spans |
| `aspire dashboard run` (CLI + dashboard process tree) | 192 MB CLI + 92 MB dashboard | **381 MB RSS / 359 MB PSS** idle → 390 MB after 1,000 spans → **401 MB** after 11,000 spans |

### GC variants (standalone dashboard RSS, idle / after 11k spans)

| Setting | Idle | After 11k spans |
|---|---|---|
| default | 136 MB | 163 MB |
| `DOTNET_gcServer=0` | 139 MB | 167 MB |
| `DOTNET_gcServer=1` | 136 MB | 158 MB |
| `DOTNET_GCHeapHardLimit=0x4000000` (64 MB) | 133 MB | 148 MB |
| `DOTNET_GCConserveMemory=7` | 146 MB | 171 MB |

About **73 MB** of the dashboard's idle RSS is the mapped native binary. Windows Task Manager's default Memory column (private working set) therefore shows much lower numbers for the same processes; RSS is what counts against a typical cloud-environment memory limit.

## Reproduce

### 1. Download the dashboard binary

```bash
./download.sh
# optional: also fetch CLI packages for the on-disk size comparison
DOWNLOAD_CLI=1 ./download.sh
```

`VERSION` defaults to `13.6.0`. Packages come from `https://api.nuget.org/v3-flatcontainer/`.

### 2. Python venv for the span generator

```bash
python3 -m venv venv
venv/bin/pip install -r requirements.txt
```

### 3. Standalone dashboard

```bash
./run_dash.sh default
# GC variants:
./run_dash.sh gcServer0 DOTNET_gcServer=0
./run_dash.sh hardlimit64 DOTNET_GCHeapHardLimit=0x4000000
```

`DASH_DIR` defaults to `./aspire.dashboard.sdk.linux-x64/tools`. Override if you unpack elsewhere.

### 4. Via the Aspire CLI

Install the CLI first, e.g. `dotnet tool install -g Aspire.Cli --version 13.6.0`, or set `ASPIRE_BIN` to the binary path. Then:

```bash
./run_cli.sh cli
```

`run_cli.sh` sums RSS/PSS over the whole process tree (CLI + child dashboard).

### Ports

Both runners use `http://localhost:18888` (UI), `:4317` (OTLP gRPC), and `:4318` (OTLP HTTP). Free those ports before starting.

## Layout

| File | Role |
|---|---|
| `download.sh` | Fetch and unzip NuGet packages |
| `run_dash.sh` | Standalone `Aspire.Dashboard` binary |
| `run_cli.sh` | `aspire dashboard run` (process tree) |
| `mem.sh` | Print RSS/PSS for one or more PIDs |
| `traffic.py` | Send synthetic OTLP traces (`demo-api-*`) |
| `requirements.txt` | OpenTelemetry SDK + OTLP exporters |

## License

MIT — see [LICENSE](LICENSE).
