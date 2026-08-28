class_name WishArchiveBook
extends Resource
## Top-level Resource wrapper for serializing WishArchive's full entry
## list -- a plain script class_name (not an anonymous inner class)
## deserializes reliably, unlike an inline Resource type.

@export var entries: Array[WishArchiveEntry] = []
