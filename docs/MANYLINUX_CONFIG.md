<!--
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Manylinux Configuration

## Overview

This document describes the manylinux platform tag configuration for Python
wheel builds using the `python-build-action`. The action uses `auditwheel`
to repair wheels for broad PyPI and pip compatibility across different
Linux distributions.

## What is Manylinux?

Manylinux is a standard for building Python wheels that work across
Linux distributions. Different manylinux versions target different base
glibc versions:

| Tag              | glibc Version | Compatible Distributions           |
| ---------------- | ------------- | ---------------------------------- |
| `manylinux2014`  | 2.17          | RHEL 7+, Ubuntu 14.04+, Debian 8+  |
| `manylinux_2_28` | 2.28          | RHEL 8+, Ubuntu 20.04+, Debian 11+ |
| `manylinux_2_34` | 2.34          | RHEL 9+, Ubuntu 22.04+, Fedora 35+ |
| `manylinux_2_35` | 2.35          | Ubuntu 23.04+, Fedora 36+          |

## Action Parameters

The `python-build-action` provides two parameters for wheel repair:

### `auditwheel`

- **Type**: boolean
- **Default**: `false`
- **Description**: Enable/disable auditwheel wheel repair
- **Usage**: Set to `true` to repair wheels for manylinux compatibility

### `manylinux_version`

- **Type**: string
- **Default**: `manylinux_2_34`
- **Description**: Target manylinux platform tag
- **Valid values**:
  - `manylinux2014` - glibc 2.17+
  - `manylinux_2_28` - glibc 2.28+
  - `manylinux_2_34` - glibc 2.34+
  - `manylinux_2_35` - glibc 2.35+
  - Any other valid manylinux tag

## Usage Examples

### Basic Usage with Default (manylinux_2_34)

<!-- markdownlint-disable MD013 -->

```yaml
- name: Build Python Wheel
  uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
  with:
    auditwheel: true
    build_formats: wheel
```

This produces wheels compatible with glibc 2.34+ (default).

### Widest Compatibility (manylinux2014)

```yaml
- name: Build Python Wheel
  uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
  with:
    auditwheel: true
    manylinux_version: manylinux2014
    build_formats: wheel
```

Best for broadest compatibility with older systems (glibc 2.17+).

### Enterprise/LTS Systems (manylinux_2_28)

```yaml
- name: Build Python Wheel
  uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
  with:
    auditwheel: true
    manylinux_version: manylinux_2_28
    build_formats: wheel
```

Targets RHEL 8+ and Ubuntu 20.04 LTS+ (glibc 2.28+).

### Multi-Architecture Builds

```yaml
jobs:
  build:
    strategy:
      matrix:
        arch: [x86_64, aarch64]
        runner:
          - arch: x86_64
            runner: ubuntu-latest
          - arch: aarch64
            runner: ubuntu-24.04-arm
    runs-on: ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v4
      - name: Build Wheel
        uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
        with:
          auditwheel: true
          manylinux_version: manylinux_2_34
```

Produces wheels for both x86_64 and ARM64 architectures.

### Without Auditwheel (Not Recommended for PyPI)

```yaml
- name: Build Python Wheel
  uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
  with:
    auditwheel: false
    build_formats: wheel
```

<!-- markdownlint-enable MD013 -->

This produces wheels with platform-specific tags (e.g., `linux_x86_64.whl`)
which PyPI will reject.

## How Auditwheel Works

When you set `auditwheel: true`, the action:

1. **Builds** the wheel using your project's build backend
2. **Analyzes** the wheel to check library dependencies
3. **Repairs** the wheel by:
   - Bundling necessary shared libraries into the wheel
   - Updating the platform tag to manylinux_*
   - Ensuring glibc compatibility
4. **Validates** that the wheel meets manylinux standards

### Auditwheel Process

```bash
# What happens during the build:
auditwheel show package-*.whl

# Then repair the wheel:
auditwheel repair package-*.whl \
  --plat-name manylinux_2_34 \
  -w wheelhouse/
```

### Fallback Behavior

If `auditwheel repair` fails:

- The action logs a warning
- The action keeps the original wheel
- The build continues (does not fail)

This allows the action to build wheels even if repair isn't possible.

## Choosing a Manylinux Version

### Factors to Consider

1. **Target Audience**: What distributions do your users run?
2. **Dependencies**: What glibc version do your C extensions require?
3. **System Libraries**: What base versions do you need?
4. **Compatibility vs. Features**: Older tags = more compatibility, newer
   tags = access to modern features

### Decision Matrix

<!-- markdownlint-disable MD013 -->

| Use Case                      | Recommended Tag  | Reason                                |
| ----------------------------- | ---------------- | ------------------------------------- |
| Broadest compatibility        | `manylinux2014`  | Works on RHEL 7+, Ubuntu 14.04+       |
| Modern systems                | `manylinux_2_34` | Ubuntu 22.04 LTS+, Fedora 35+         |
| Enterprise/LTS                | `manylinux_2_28` | RHEL 8+, Ubuntu 20.04 LTS+            |
| Latest features               | `manylinux_2_35` | Recent distributions                  |
| C extensions with modern deps | `manylinux_2_34` | Balance of compatibility and features |

<!-- markdownlint-enable MD013 -->

### Recommendations

**For most projects**: Use the default `manylinux_2_34` for modern systems
(Ubuntu 22.04 LTS+, RHEL 9+).

**If you need widest compatibility**: Use `manylinux2014` to support older
systems (RHEL 7+, Ubuntu 14.04+).

**If targeting enterprise LTS**: Use `manylinux_2_28` to support RHEL 8 and
Ubuntu 20.04 LTS.

## Verification

### Check Wheel Platform Tag

After building, verify the wheel has the correct tag:

```bash
# Example wheel filename:
package-1.0.0-cp310-cp310-manylinux_2_34_x86_64.whl
                            ^^^^^^^^^^^^^^^^
                            Platform tag
```

### Inspect Wheel Contents

```bash
# Check for bundled shared libraries:
unzip -l package-*.whl | grep "\.so"

# Install and use the inspection tool:
pip install auditwheel && auditwheel show package-*.whl
```

### Test on Target System

```bash
# On a system matching your target manylinux version:
pip install package-*.whl
python -c "import package; package.test()"
```

## PyPI Requirements

PyPI has strict requirements for platform tags:

- ✅ **Accepted**: `manylinux_*` tags
- ✅ **Accepted**: `musllinux_*` tags (for Alpine Linux)
- ❌ **Rejected**: `linux_*` tags
- ❌ **Rejected**: Platform-specific tags without manylinux prefix

**Always use auditwheel** when building wheels for PyPI distribution.

## Troubleshooting

### Wheel Rejected by PyPI

**Error**: "Invalid platform tag: linux_x86_64"

**Solution**: Enable auditwheel in your workflow:

```yaml
with:
  auditwheel: true
```

### Incompatible with Older Systems

**Error**: "ImportError: /lib64/libc.so.6: version 'GLIBC_2.34' not found"

**Cause**: Wheel built with `manylinux_2_34` on system with older glibc.

**Solution**: Build with an older manylinux version:

```yaml
with:
  auditwheel: true
  manylinux_version: manylinux_2_28
```

### Auditwheel Repair Fails

**Error**: "cannot repair to manylinux_2_34 due to non-conformant library"

**Possible causes**:

1. Wheel depends on libraries not available in the target glibc
2. System libraries are too new for the target
3. Missing library dependencies

**Solutions**:

- Try a newer manylinux version: `manylinux_2_35`
- Check your C extension's dependencies
- Build dependencies from source with appropriate flags
- Use a build container matching your target manylinux version

### Auditwheel Not Found

**Error**: "auditwheel: command not found"

**Cause**: Action installs auditwheel when `auditwheel: true`.

**Solution**: This shouldn't happen in the action, but if manually running:

```bash
pip install auditwheel
```

### Wrong Platform Tag After Repair

**Error**: Wheel still has `linux_x86_64` tag after repair.

**Cause**: Auditwheel repair failed and kept original wheel.

**Solution**: Check the action logs for auditwheel warnings. You may need to
adjust your manylinux version or fix dependency issues.

## Architecture Support

The action supports these architectures:

<!-- markdownlint-disable MD013 -->

| Architecture    | Platform Tag Suffix | Wheel Example                |
| --------------- | ------------------- | ---------------------------- |
| x86_64          | `_x86_64`           | `manylinux_2_34_x86_64.whl`  |
| aarch64 (ARM64) | `_aarch64`          | `manylinux_2_34_aarch64.whl` |
| i686 (32-bit)   | `_i686`             | `manylinux_2_34_i686.whl`    |

<!-- markdownlint-enable MD013 -->

Auditwheel handles architecture detection automatically.

## Integration with CI/CD

### GitHub Actions Example

<!-- markdownlint-disable MD013 -->

```yaml
name: Build and Publish

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      matrix:
        arch:
          - runner: ubuntu-latest
            platform: x86_64
          - runner: ubuntu-24.04-arm
            platform: aarch64
        python-version: ['3.9', '3.10', '3.11', '3.12']

    runs-on: ${{ matrix.arch.runner }}

    steps:
      - uses: actions/checkout@v4

      - name: Build Wheel
        uses: lfreleng-actions/python-build-action@3552106f5c8bfedebe4c38116abf3b9c289359ea  # v0.1.22
        with:
          python_version: ${{ matrix.python-version }}
          auditwheel: true
          manylinux_version: manylinux_2_34
          build_formats: wheel
          artefact_name: wheels-${{ matrix.arch.platform }}-py${{ matrix.python-version }}
          # Creates separate artifact names like: wheels-x86_64-py3.10, wheels-aarch64-py3.11

      - name: Publish to PyPI
        if: startsWith(github.ref, 'refs/tags/')
        uses: pypa/gh-action-pypi-publish@release/v1
```

<!-- markdownlint-enable MD013 -->

## Best Practices

1. **Enable Auditwheel for PyPI**: Always use `auditwheel: true` for PyPI
   uploads

2. **Test on Target Systems**: Verify wheels work on the base supported
   OS version

3. **Document Requirements**: State base OS requirements in your
   README

4. **Use Matrix Builds**: Build for different architectures (x86_64, aarch64)

5. **Pin Manylinux Version**: Explicitly set `manylinux_version` rather than
   relying on default

6. **Review Logs**: Check auditwheel output in CI logs for warnings

7. **Verify Before Release**: Download and test wheels before publishing to
   PyPI

## References

- [PEP 600 -- Future manylinux platform tags](https://peps.python.org/pep-0600/)
- [PEP 599 -- manylinux2014 platform tag](https://peps.python.org/pep-0599/)
- [PEP 571 -- manylinux2010 platform tag](https://peps.python.org/pep-0571/)
- [Auditwheel Documentation](https://github.com/pypa/auditwheel)
<!-- markdownlint-disable-next-line MD013 -->
- [Python Packaging User Guide](https://packaging.python.org/en/latest/guides/distributing-packages-using-setuptools/#platform-wheels)
- [Manylinux GitHub Repository](https://github.com/pypa/manylinux)

## Summary

- **Default**: `auditwheel: false`, `manylinux_version: manylinux_2_34`
- **Recommendation**: Enable auditwheel for PyPI distribution
- **Modern Systems**: `manylinux_2_34` (default) for Ubuntu 22.04 LTS+, RHEL 9+
- **Widest Compatibility**: `manylinux2014` for older systems
- **Supported Architectures**: x86_64, aarch64, i686
- **Fallback**: Original wheel kept if repair fails
