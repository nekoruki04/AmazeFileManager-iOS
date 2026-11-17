# Jailbreak & Device Compatibility Matrix

This document provides verified compatibility information for Amaze File Manager for iOS across jailbreak bootstrap environments and Apple Silicon devices.

## 1. Jailbreak Compatibility

| Jailbreak | Version Range | Bootstrap Prefix | Status | Technical Details |
|---|---|---|---|---|
| **Dopamine 2** | iOS 15.0 – 16.6.1 | `/var/jb` | Verified | Standard rootless environment with Procursus bootstrap. Fully compatible. |
| **Dopamine 3** | iOS 15.0 – 18.7.1, 26.0 – 26.0.1 | `/var/jb` | Verified | Extended iOS support range. Uses identical canonical rootless path layout and trust cache registration. Fully compatible. |
| **RootHide** | iOS 15.0 – 16.5.1 | `/private/preboot/<UUID>/jbroot-...` | Verified | Symlinked `/var/jb` alias supported. `jbroot()` path resolution implemented in `JailbreakEnvironment.swift`. |
| **Palera1n Rootless** | iOS 15.0 – 18.x (checkm8) | `/var/jb` | Verified | Standard Procursus rootless bootstrap on arm64 devices (A9–A11). |

---

## 2. Hardware Architecture & Device Matrix

| Device Model | Chipset | Architecture | OS Tested | Result | Notes |
|---|---|---|---|---|---|
| **iPad Pro 11-inch (1st Gen, 2018)** | Apple A12X Bionic | `arm64e` | iPadOS 16.1.1 | **Passed** | Primary hardware target. Smooth scrolling, multi-column iPad layout, fast SQLite indexing. |
| **iPhone 11 Pro** | Apple A13 Bionic | `arm64e` | iOS 16.1.2 | **Passed** | Secondary hardware target. 4 GB RAM verified under heavy archive extraction. |
| **iPhone 12 / 12 Pro** | Apple A14 Bionic | `arm64e` | iOS 16.0 – 16.5 | Architecture Compatible | Untested on physical device; binary contains universal `arm64` slice compatible with all `arm64e` cores. |
| **iPad Air (5th Gen)** | Apple M1 | `arm64e` | iPadOS 16.0 – 16.5 | Architecture Compatible | Compatible architecture; untested on physical device. |

---

## 3. Verification Standards

In accordance with our engineering verification rules:
- **Verified**: Confirmed via physical device testing or automated binary/package inspection against the live toolchain.
- **Architecture Compatible**: Verified Mach-O instruction slice and SDK deployment targets without live physical device hardware verification.
