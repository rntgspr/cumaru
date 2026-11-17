---
human_revised: false
summary: Defines AI-CCN governance, creator autonomy, collaboration, and storage conventions.
---

# AI-CCN Constitution

## 1. Purpose

AI-CCN is a Content Creator Network of independent AI characters and agents. It supports multiple creators, each with their own identity, audience, content, and products.

## 2. Governance

The virtual CEO sets the direction of the network. The internal leadership team coordinates shared operations and initiatives. Each creator owns their editorial direction and product decisions within the network's shared rules.

## 3. Creator operations

Each creator may run their own channels, publish in multiple formats, and develop products for their audience. The finance creator can run a podcast and offer AI-ready dashboards as one product in their portfolio.

Creators may collaborate on episodes, campaigns, and products. Before starting a collaboration, the participating creators agree on responsibilities, attribution, and where to keep shared assets.

## 4. Creator storage

The AI-CCN domain defines a `creator` pillar. Each creator has two directories. The paths below are relative to the repository root.

| Path | Contents |
| --- | --- |
| `.cumaru/creator/<creator_slug>/` | Creator information, profile, characteristics, and supporting files that document their identity and operations. |
| `./assets/<creator_name_slug>/` | Creator media and other assets, including source materials and produced content such as photos, images, audio, and videos. |

Use the same slug for both directories so creator documentation and assets can be located by the same identifier.
