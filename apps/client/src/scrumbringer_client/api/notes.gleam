//// Shared client API helpers for note endpoints.

import gleam/dynamic/decode
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/note/entity.{type Note}
import domain/note/note_codec
import scrumbringer_client/api/core

pub fn list(
  path: String,
  to_msg: fn(ApiResult(List(Note))) -> msg,
) -> Effect(msg) {
  core.request(core.Get, path, option.None, notes_decoder(), to_msg)
}

pub fn create(
  path: String,
  content: String,
  url: option.Option(String),
  to_msg: fn(ApiResult(Note)) -> msg,
) -> Effect(msg) {
  core.request(
    core.Post,
    path,
    option.Some(note_body(content, url)),
    note_decoder(),
    to_msg,
  )
}

pub fn set_pinned(
  path: String,
  pinned: Bool,
  to_msg: fn(ApiResult(Note)) -> msg,
) -> Effect(msg) {
  let method = case pinned {
    True -> core.Post
    False -> core.Delete
  }
  let body = case pinned {
    True -> option.Some(json.object([]))
    False -> option.None
  }

  core.request(method, path, body, note_decoder(), to_msg)
}

pub fn delete(path: String, to_msg: fn(ApiResult(Nil)) -> msg) -> Effect(msg) {
  core.request_nil(core.Delete, path, option.None, to_msg)
}

fn notes_decoder() -> decode.Decoder(List(Note)) {
  decode.field("notes", decode.list(note_codec.note_decoder()), decode.success)
}

fn note_decoder() -> decode.Decoder(Note) {
  decode.field("note", note_codec.note_decoder(), decode.success)
}

fn note_body(content: String, url: option.Option(String)) -> json.Json {
  let url_json = case url {
    option.Some(value) -> json.string(value)
    option.None -> json.null()
  }
  json.object([#("content", json.string(content)), #("url", url_json)])
}
