<!--
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# 🐍 Build Python Project

Builds a Python project, uploads/stores artefacts in GitHub.

Supports these optional features:

- GitHub Attestations (Build Provenance)
- SigStore Signing    (Signing of Build Artefacts)

## python-build-action

## Usage Example

### Minimal Example

<!-- markdownlint-disable MD013 -->
<!-- markdownlint-disable MD046 -->

```yaml
name: Build Python Project

on:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: 'Checkout repository'
        uses: actions/checkout@v4

      - name: 'Build Python project'
        uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
```

<!-- markdownlint-enable MD046 -->
<!-- markdownlint-disable MD013 -->

### Advanced Example with Attestations and Signing

<!-- markdownlint-disable MD046 -->
<!-- markdownlint-disable MD013 -->

```yaml
name: Build and Sign Python Project

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: read
  id-token: write       # Required for attestations and Sigstore
  attestations: write   # Required for GitHub attestations

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: 'Checkout repository'
        uses: actions/checkout@v4

      - name: 'Build Python project'
        uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
        with:
          attestations: true
          sigstore_sign: true
```

<!-- markdownlint-enable MD013 -->
<!-- markdownlint-enable MD046 -->

### Multi-Architecture Build Example

When building for different architectures (e.g., x64 and ARM64), use the
`artefact_name` input to avoid artefact name conflicts:

<!-- markdownlint-disable MD046 -->
<!-- markdownlint-disable MD013 -->

```yaml
name: Multi-Architecture Build

on:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  build-x64:
    runs-on: ubuntu-latest
    steps:
      - name: 'Checkout repository'
        uses: actions/checkout@v4

      - name: 'Build Python project (x64)'
        uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
        with:
          artefact_name: my-package-x64

  build-arm64:
    runs-on: ubuntu-24.04-arm
    steps:
      - name: 'Checkout repository'
        uses: actions/checkout@v4

      - name: 'Build Python project (ARM64)'
        uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
        with:
          artefact_name: my-package-arm64
```
<!-- markdownlint-enable MD013 -->
<!-- markdownlint-enable MD046 -->

## Inputs

<!-- markdownlint-disable MD013 -->

| Variable Name       | Required | Default        | Description                                                 |
| ------------------- | -------- | -------------- | ----------------------------------------------------------- |
| artefact_name       | False    |                | Custom name for uploaded artefacts (default: project name)  |
| artefact_path       | False    | "dist"         | Output path/directory to use for build artefacts            |
| artefact_upload     | False    | true           | Uploads artefacts once build completes                      |
| purge_artefact_path | False    | false          | Deletes any pre-existing content in build/target directory  |
| tag                 | False    |                | Explicit tag/version to use for project build               |
| attestations        | False    | false          | Attest build artefacts using GitHub Attestations            |
| sigstore_sign       | False    | false          | Uses SigStore to sign binary build artefacts                |
| path_prefix         | False    |                | Path/directory to Python project code                       |
| tox_build           | False    | false          | Builds using tox, if configuration file exists              |
| skip_version_patch  | False    | false          | Skip version patching (support dynamic versioning)          |
| python_version      | False    |                | Override Python version for build (uses metadata if unset)  |
| clear_cache         | False    | false          | Clears Python dependency caches                             |
| build_formats       | False    | both           | Build formats: wheel, sdist, or both                        |
| auditwheel          | False    | false          | Run auditwheel to repair wheels for manylinux compatibility |
| manylinux_version   | False    | manylinux_2_34 | Target manylinux version for auditwheel                     |
| make                | False    | false          | Run make before building                                    |
| make_args           | False    |                | Arguments/flags sent to make command                        |

<!-- markdownlint-enable MD013 -->

### Input Notes

- When building for different platforms/architectures, use `artefact_name`
  to avoid artefact name conflicts.
- The `make` input is useful for Python projects with C extensions or other
  compiled components that require build preparation steps via make before
  the Python build process. Use `make_args` to pass specific targets or
  flags.
- Do not enable attestations or signing for development/test builds.

See the following links for more information on artefact signing and
attestations:

- [GitHub Attestations][GitHub Attestations]
- [SigStore](https://www.sigstore.dev/)

## Required Permissions

Different features require different permission levels:

### Basic Build (Default)

```yaml
permissions:
  contents: read
```

### With Cache Clearing

```yaml
permissions:
  contents: read
  actions: write  # Required for cache deletion
```

### With Attestations and/or Signing

```yaml
permissions:
  contents: read
  id-token: write       # Required for Sigstore signing
  attestations: write   # Required for GitHub attestations
```

**Important:** Check out the repository before using this action. Use
`actions/checkout@v4` or later in a prior step.

## Outputs

<!-- markdownlint-disable MD013 -->

| Variable Name        | Description                                    |
| -------------------- | ---------------------------------------------- |
| build_python_version | Python version used to perform build           |
| matrix_json          | Project supported Python versions as JSON      |
| artefact_name        | Project name used for build artefacts          |
| artefact_path        | Full path to build artefacts directory         |

<!-- markdownlint-enable MD013 -->

## Build Versioning

This action supports three versioning strategies:

1. **Tag Push Events**: When a tag push triggers the action (e.g.,
   `v1.0.0`), the build version matches the pushed tag.
2. **Explicit Versioning**: Use the `tag` input to specify a version. The
   action patches the project metadata file to match.
3. **Project-defined Versioning**: If no tag triggers the action, the
   version comes from `pyproject.toml` or `setup.py`.
   - **Dynamic Versioning:** For projects using dynamic versioning (e.g.,
     `setuptools-scm`, `poetry-dynamic-versioning`), set
     `skip_version_patch: true` to preserve the dynamic behavior.

**Version Patching Behavior:**

- Patching occurs when: you provide `tag` AND it differs from the project
  version AND the action does not detect dynamic versioning.
- Patching skips when: `skip_version_patch: true` OR versioning uses
  dynamic mode OR the tag matches the project version.

## Build Process/Steps

The action performs the following steps to build the project:

- Gather project metadata from the relevant file(s)
- Tag/version consistency check (production builds/tag push events)
- Patch project metadata to match build version (explicit versioning)
- Setup Python environment using information extracted from project
  metadata
- Install build dependencies
- **Build Python project**
- Repair wheels with auditwheel (if enabled)
- Output build summary
- Test build artefacts with Twine
- GitHub build attestation (production builds/tag push events)
- Sign artefacts with SigStore (production builds/tag push events)
- Upload build artefacts to GitHub

## Build Mechanism

This build action follows modern PEP standards (PEP 517/518/621).

## Caching

This action automatically caches Python dependencies for all major
dependency managers (pip, poetry, pipenv) and build backends. The cache
key includes the OS, Python version, and a hash of all relevant dependency
files (`requirements.txt`, `pyproject.toml`, `poetry.lock`, `Pipfile*`,
`setup.py`, `setup.cfg`).

This ensures reliable, up-to-date builds for all supported Python project
types.

### Cache Clearing

To clear all Python dependency caches for the repository, set the
`clear_cache` input to `true`. This performs the following:

1. Delete all existing Python dependency caches, unconditionally
2. Force fresh installation of all dependencies
3. Create a new cache for future workflow runs

Use this when:

- Troubleshooting dependency resolution issues
- Testing with new Python versions where cached dependencies are problematic
- Ensuring a clean build environment

**Note:** Requires `actions: write` permission in the workflow (see
[Required Permissions](#required-permissions) section).

Example with `workflow_dispatch`:

<!-- markdownlint-disable MD013 -->

```yaml
on:
  workflow_dispatch:
    inputs:
      clear_cache:
        description: 'Clear all Python dependency caches'
        type: boolean
        default: false

jobs:
  build:
    permissions:
      contents: read
      actions: write  # Required for cache deletion
    steps:
      - name: 'Checkout repository'
        uses: actions/checkout@v4
      - name: 'Build Python project'
        uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
        with:
          clear_cache: ${{ github.event.inputs.clear_cache }}
```

<!-- markdownlint-enable MD013 -->

## Notes

When you set `purge_artefact_path` to `true`, `actions/upload-artefacts`
permits overwriting pre-existing artefacts.

### Limitations

The following features have not undergone extensive testing with this action:

- **Legacy project types** (`setup.py`, `setup.cfg` without `pyproject.toml`)

While projects of this types may work, consider current support experimental.

<!-- markdownlint-disable MD013 -->

[GitHub Attestations]: https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds

<!-- markdownlint-enable MD013 -->
