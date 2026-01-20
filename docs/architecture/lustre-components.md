# Lustre Components Architecture

> **Version:** 1.0
> **Parent:** [Architecture](../architecture.md)
> **Reference:** [Lustre Component API](https://hexdocs.pm/lustre/lustre/component.html)

---

## Overview

Lustre Components provide Shadow DOM-based encapsulation for self-contained UI features. This document establishes patterns for when and how to extract features into components.

---

## When to Componentize

### Criteria Checklist

Apply componentization when ALL of the following are true:

| Criterion | Threshold | Rationale |
|-----------|-----------|-----------|
| Model fields | ≥8 fields | Significant state bloat in root Model |
| Msg variants | ≥7 variants | Significant message bloat in root Msg |
| Self-contained | No cross-reads | Doesn't need to read unrelated Model fields |
| Unidirectional | Events out, props in | Clear parent-child boundary |
| Reusable | ≥1 usage site | Or strong potential for reuse |

### Do NOT Componentize When

- Feature has <6 Model fields (overhead not justified)
- Feature requires reading multiple unrelated Model fields
- Feature has circular dependencies with other features
- Feature is deeply integrated into routing/navigation

---

## Component Structure

### File Layout

```
apps/client/src/scrumbringer_client/
├── components/
│   ├── card_detail_modal.gleam    # Component module
│   └── card_crud_dialog.gleam     # Future component
├── component.ffi.mjs              # Shared FFI for custom events
```

### Module Template

```gleam
//// Component Name.
////
//// ## Mission
////
//// [One sentence describing what this component does]
////
//// ## Responsibilities
////
//// - [Responsibility 1]
//// - [Responsibility 2]
////
//// ## Relations
////
//// - Parent: [which module renders this component]
//// - API: [which API modules it uses]

import gleam/dynamic/decode.{type Decoder}
import gleam/json
import gleam/option.{type Option}
import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}

// =============================================================================
// Internal Types
// =============================================================================

/// Internal component model - encapsulated state.
pub type Model {
  Model(
    // Required props from parent
    entity_id: Option(Int),
    locale: Locale,
    // Internal state
    form_field: String,
    in_flight: Bool,
    error: Option(String),
  )
}

/// Internal messages - not exposed to parent.
pub type Msg {
  // From attributes/properties
  EntityIdReceived(Int)
  LocaleReceived(Locale)
  // Internal state
  FieldChanged(String)
  SubmitClicked
  SubmitResult(ApiResult(Entity))
  CloseClicked
}

// =============================================================================
// Component Registration
// =============================================================================

/// Register the component as a custom element.
/// Call this once at app init.
pub fn register() -> Result(Nil, lustre.Error) {
  lustre.component(init, update, view, on_attribute_change())
  |> lustre.register("component-name")
}

fn on_attribute_change() -> List(component.Option(Msg)) {
  [
    component.on_attribute_change("entity-id", decode_entity_id),
    component.on_attribute_change("locale", decode_locale),
    component.on_property_change("entity", entity_decoder()),
    component.adopt_styles(True),
  ]
}

// =============================================================================
// Init / Update / View
// =============================================================================

fn init(_: Nil) -> #(Model, Effect(Msg)) {
  #(default_model(), effect.none())
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    // Handle messages...
    CloseClicked -> #(model, emit_close_requested())
    _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  // Render component...
}

// =============================================================================
// Custom Event Emission
// =============================================================================

fn emit_close_requested() -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("close-requested", json.null())
  })
}

@external(javascript, "../component.ffi.mjs", "emit_custom_event")
fn emit_custom_event(_name: String, _detail: json.Json) -> Nil {
  Nil
}
```

---

## Parent Integration

### Rendering the Component

```gleam
fn view_component(model: Model) -> Element(Msg) {
  case model.dialog_open {
    option.None -> element.none()
    option.Some(entity_id) -> {
      let entity = find_entity(model, entity_id)

      element.element(
        "component-name",
        [
          // Attributes (strings only)
          attribute.attribute("entity-id", int.to_string(entity_id)),
          attribute.attribute("locale", locale.serialize(model.locale)),
          // Properties (JSON objects)
          attribute.property("entity", entity_to_json(entity)),
          // Event listeners
          event.on("close-requested", decode.success(CloseDialog)),
          event.on("entity-saved", decode.success(RefreshData)),
        ],
        [],
      )
    }
  }
}
```

### Parent State (Minimal)

The parent should only retain:

```gleam
pub type Model {
  Model(
    // Only the "open" state - component manages everything else
    dialog_open: Option(Int),  // or Option(DialogMode) for create/edit
    // ...other unrelated fields
  )
}

pub type Msg {
  // Only open/close messages - component handles internal messages
  OpenDialog(Int)
  CloseDialog
  RefreshData  // Triggered by component events
  // ...other unrelated messages
}
```

---

## Communication Patterns

### Props In (Parent → Component)

| Type | Mechanism | Use Case |
|------|-----------|----------|
| Strings | `attribute.attribute()` | IDs, locale, simple values |
| Objects | `attribute.property()` | Entities, lists, complex data |

### Events Out (Component → Parent)

| Event | Payload | When |
|-------|---------|------|
| `close-requested` | `null` | User clicks close/cancel |
| `entity-created` | `{ id: Int }` | After successful create |
| `entity-updated` | `{ id: Int }` | After successful update |
| `entity-deleted` | `{ id: Int }` | After successful delete |

### FFI for Custom Events

```javascript
// component.ffi.mjs
export function emit_custom_event(name, detail) {
  const component = globalThis.__LUSTRE_CURRENT_COMPONENT__

  if (!component || !component.dispatchEvent) {
    console.warn(`[component.ffi] Cannot emit "${name}": no component context`)
    return
  }

  const event = new CustomEvent(name, {
    bubbles: true,
    composed: true,  // Required for Shadow DOM traversal
    detail: detail,
  })

  component.dispatchEvent(event)
}
```

---

## JSON Serialization

Components receive complex data as JSON properties. Define serializers in the parent view module:

```gleam
fn entity_to_json(entity: Entity) -> json.Json {
  json.object([
    #("id", json.int(entity.id)),
    #("name", json.string(entity.name)),
    #("status", json.string(status_to_string(entity.status))),
    #("optional_field", case entity.optional {
      option.Some(v) -> json.string(v)
      option.None -> json.null()
    }),
  ])
}
```

Components define decoders for their properties:

```gleam
fn entity_decoder() -> Decoder(Msg) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use status <- decode.field("status", status_decoder())
  decode.success(EntityReceived(Entity(id, name, status)))
}
```

---

## Testing Components

### Test File Location

```
apps/client/test/{component_name}_test.gleam
```

### What to Test

1. **Model construction** - Default values, field retention
2. **Msg constructors** - Type safety of message variants
3. **State types** - Remote, enums, options

### Example Tests

```gleam
pub fn initial_model_has_correct_defaults_test() {
  let model = make_model()

  model.entity_id |> should.equal(option.None)
  model.in_flight |> should.equal(False)
  model.error |> should.equal(option.None)
}

pub fn entity_received_msg_carries_data_test() {
  let EntityReceived(entity) = EntityReceived(make_entity(42))
  entity.id |> should.equal(42)
}
```

### Note on Update Testing

The `update` function is private to maintain encapsulation. Test state transitions indirectly through:
- Model construction patterns
- Integration tests via Playwright

---

## Registration

Components must be registered once at app initialization:

```gleam
// In scrumbringer_client.gleam main()
pub fn main() {
  // Register all components
  case card_detail_modal.register() {
    Ok(_) -> Nil
    Error(_) -> Nil  // Log error in production
  }

  case card_crud_dialog.register() {
    Ok(_) -> Nil
    Error(_) -> Nil
  }

  // Start the app...
}
```

---

## Componentization Candidates

Based on current codebase analysis:

| Candidate | Model Fields | Msg Variants | Priority | Status |
|-----------|-------------|--------------|----------|--------|
| Card Detail Modal | 11 | 12 | - | DONE |
| Admin Cards CRUD | 13 | 17 | HIGH | Planned |
| Workflows CRUD | 10 | 14 | HIGH | Planned |
| Task Templates CRUD | 11 | 15 | HIGH | Planned |
| Rules CRUD | 16 | 23 | MEDIUM | Planned |
| Task Types | 8 | 8 | LOW | - |
| Capabilities | 6 | 5 | - | Too small |

### Estimated Impact

| Phase | Components | Model Reduction | Msg Reduction |
|-------|------------|-----------------|---------------|
| 1 | Cards, Workflows, TaskTemplates | ~34 fields | ~46 variants |
| 2 | Rules | ~16 fields | ~23 variants |
| **Total** | 4 components | **~50 fields** | **~69 variants** |

---

## Style Inheritance

Components use `adopt_styles(True)` to inherit CSS custom properties:

```gleam
fn on_attribute_change() -> List(component.Option(Msg)) {
  [
    // ...other options
    component.adopt_styles(True),  // Inherit --sb-* CSS variables
  ]
}
```

This allows components to use theme colors defined in the parent document:

```css
/* In component view */
.dialog-header {
  background: var(--sb-surface);
  color: var(--sb-text);
  border-color: var(--sb-border);
}
```

---

## Checklist for New Components

- [ ] Create module in `components/` directory
- [ ] Add Mission/Responsibilities/Relations documentation
- [ ] Define internal Model and Msg types
- [ ] Implement `register()` function
- [ ] Define attribute/property decoders
- [ ] Implement custom event emission
- [ ] Add `adopt_styles(True)` for theming
- [ ] Create parent integration with JSON serializers
- [ ] Register in `scrumbringer_client.main()`
- [ ] Write unit tests for types
- [ ] Remove old fields from root Model
- [ ] Remove old variants from root Msg
- [ ] Delete obsolete view modules
- [ ] Run full test suite
- [ ] Manual QA verification

---

## References

- [Lustre Component API](https://hexdocs.pm/lustre/lustre/component.html)
- [Story 3.6: Card Detail Modal](../stories/3.6.card-detail-component.md) - First implementation
- [Coding Standards](./coding-standards.md) - Module structure guidelines
