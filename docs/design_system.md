# YEO.PE iOS Design System & Theme Guide

## 1. Overview
This document defines the semantic color system and typography for the YEO.PE iOS application. The goal is to ensure consistent execution of "Dark Mode" (Cyber/Neon) and "Light Mode" (Industrial/Concrete) themes across all views, functioning similarly to CSS variables.

## 2. Color Palette Strategy

We use **Semantic Naming** instead of descriptive naming (e.g., use `bgPrimary` instead of `blackOrGray`).

### 2.1. Backgrounds
| Token Name | Dark Mode (Cyber) | Light Mode (Concrete) | Usage |
|:--- |:--- |:--- |:--- |
| `bg_main` | `#050505` (Deep Black) | `#F2F2F7` (System Gray / Concrete) | Main screen background |
| `bg_layer1` | `#000000` (w/ opacity) | `#FFFFFF` (w/ opacity) | Glassmorphism cards, bottom sheets |
| `bg_layer2` | `#1C1C1E` | `#FFFFFF` | Input fields, strictly opaque elements |

### 2.2. Text
| Token Name | Dark Mode | Light Mode | Usage |
|:--- |:--- |:--- |:--- |
| `text_primary` | `#FFFFFF` (White) | `#000000` (Black) | Headlines, Body text |
| `text_secondary` | `#8E8E93` (Gray) | `#636366` (Dark Gray) | Subtitles, Captions |
| `text_brand` | `#00FF94` (Neon Green) | `#000000` (Black) | Special brand text (if adaptable) |

### 2.3. Accents & Borders
| Token Name | Dark Mode | Light Mode | Usage |
|:--- |:--- |:--- |:--- |
| `accent_primary` | `#00FF94` (Neon Green) | `#1C1C1E` (Dark Charcoal) | Buttons, Icons, Active States |
| `border_primary` | `#00FF94` (30% Opacity) | `#1C1C1E` (30% Opacity) | Card borders, Dividers |
| `accent_secondary`| `#7000FF` (Violet) | `#5856D6` (Deep Purple) | Ghost mode, Secondary actions |
| `signal_error` | `#FF3B30` | `#FF3B30` | Alerts, Delete actions |

## 3. Implementation Plan

### Step 1: Centralize Definitions (`DesignSystem.swift`)
Refactor `DesignSystem.swift` to include a `YeoPeColors` struct (or standard `Color` extension) that strictly defines these semantic tokens.

### Step 2: Refactor Views
Systematically replace hardcoded colors (`Color.black`, `Color.white`, `Color(.systemGray)`) with semantic tokens (`Color.theme.bgMain`, `Color.theme.textPrimary`).

#### Target Views:
1. `MainView` (Radar, Top Bar, Bottom Bar)
2. `ProfileView` (Cards, Texts, Toggles)
3. `ChatView` (Bubbles, Backgrounds, Inputs)
4. `RoomListView` (List rows)

## 4. Typography (Existing)
* `radarHeadline`: 28pt Black
* `radarBody`: 16pt Regular
* `radarData`: 14pt Mono Medium
* `radarCaption`: 12pt Light

---

## 5. View-Specific Migration Checklist

- [ ] **MainView**: Radar background, Nodes, Bottom Glass Bar
- [ ] **ProfileView**: Bento Grid Cells, Text settings
- [ ] **ChatView**: Bubble colors (Owner vs Other), Input field
- [ ] **Login/Settings**: Form backgrounds
