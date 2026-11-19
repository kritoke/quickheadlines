require "xml"

# Fix for a permanent XML::Document leak seen on FreeBSD.
#
# XML::Document stores `self` in the libxml doc struct (`doc->_private`) so
# that `Document.new(doc_ptr)` can find the existing wrapper. When the libxml
# struct lives in memory the Boehm GC scans (FreeBSD's libgc setup does this;
# on Linux libxml uses plain malloc, which the GC never scans), this forms the
# cycle
#
#   XML::Document -> @node (libxml doc) -> _private -> XML::Document
#
# Boehm cannot finalize an object reachable from itself: it logs
# "Finalization cycle involving" and the document plus its whole parsed tree
# is never freed.
#
# We store the pointer bit-inverted so the conservative scanner never sees it
# as a reference, and invert it back on lookup. The wrapper is still kept
# alive by every XML::Node (`@document`), exactly as on Linux today; once it
# is collected its finalizer frees the libxml doc, so the hidden pointer is
# never dereferenced after the wrapper is gone.
#
# Redefining the stdlib's `Document.new(doc, errors = nil)` does not take
# effect, so these are narrower overloads that win dispatch instead. They
# cover every stdlib caller: `XML.from_ptr` (doc + errors array) and
# `Node.new` / `Reader#expand` (doc only).
class XML::Document
  # :nodoc:
  def self.new(doc : LibXML::Doc*, errors : Array(Error)) : Document
    if wrapper = from_hidden(doc)
      return wrapper
    end
    document = new(doc_: doc, errors_: errors)
    doc.value._private = hide(document)
    document
  end

  # :nodoc:
  def self.new(doc : LibXML::Doc*) : Document
    from_hidden(doc) || new(doc, [] of Error)
  end

  private def self.hide(document : Document) : Void*
    Pointer(Void).new(~document.as(Void*).address)
  end

  private def self.from_hidden(doc : LibXML::Doc*) : Document?
    if hidden = doc.value._private
      Pointer(Void).new(~hidden.address).as(Document)
    end
  end
end
