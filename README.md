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
        uses: lfreleng-actions/python-build-action@main
```

<!-- markdownlint-enable MD046 -->

### Advanced Example with Attestations and Signing

<!-- markdownlint-disable MD046 -->

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
        uses: lfreleng-actions/python-build-action@main
        with:
          attestations: true
          sigstore_sign: true
```

<!-- markdownlint-enable MD046 -->

## Inputs

<!-- markdownlint-disable MD013 -->

| Variable Name       | Required | Default | Description                                                |
| ------------------- | -------- | ------- | ---------------------------------------------------------- |
| artefact_path       | False    | "dist"  | Output path/directory to use for build artefacts           |
| artefact_upload     | False    | true    | Uploads artefacts once build completes                     |
| purge_artefact_path | False    | false   | Deletes any pre-existing content in build/target directory |
| tag                 | False    |         | Explicit tag/version to use for project build              |
| attestations        | False    | false   | Attest build artefacts using GitHub Attestations           |
| sigstore_sign       | False    | false   | Uses SigStore to sign binary build artefacts               |
| path_prefix         | False    |         | Path/directory to Python project code                      |
| tox_build           | False    | false   | Builds using tox, if configuration file exists             |
| skip_version_patch  | False    | false   | Skip version patching (support dynamic versioning)         |
| clear_cache         | False    | false   | Clears Python dependency caches                            |

<!-- markdownlint-enable MD013 -->

**Note:** Do not enable attestations or signing for development/test builds.

See the following links for more information on artefact signing and
attestations:

- [Github Attestations][Github Attestations]
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
- Output build summary
- Test build artefacts with Twine
- Github build attestation (production builds/tag push events)
- Sign artefacts with SigStore (production builds/tag push events)
- Upload build artefacts to Github

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
- Testing with Python 3.14 or other new Python versions where cached
  dependencies conflict
- Ensuring a clean build environment

**Note:** Requires `actions: write` permission in the workflow (see
[Required Permissions](#required-permissions) section).

Example with `workflow_dispatch`:

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
        uses: lfreleng-actions/python-build-action@main
        with:
          clear_cache: ${{ github.event.inputs.clear_cache }}
```

## Notes

When you set `purge_artefact_path` to `true`, `actions/upload-artefacts`
permits overwriting pre-existing artefacts.

### Limitations

The following features have not undergone extensive testing with this action:

- **Legacy project types** (`setup.py`, `setup.cfg` without `pyproject.toml`)

While projects of this types may work, consider current support experimental.

<!-- markdownlint-disable MD013 -->

[Github Attestations]: https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds

<!-- markdownlint-enable MD013 -->
