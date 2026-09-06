require "crystal/system/print_error"

# GC warning diagnostics.
#
# Stock Crystal routes Boehm GC warnings through Crystal::System.print_error,
# which formats the message with its argument. On some libgc builds (notably
# FreeBSD ports), the "Finalization cycle involving" warning prints "(???)"
# without the object address, hiding which object forms the finalizer cycle.
#
# This warn proc prints the raw message PLUS the pointer argument as an
# explicit hex line, allocation-free (warn procs may run inside GC where
# allocation is unsafe). Finalization cycles are permanent leaks by design
# (the objects can never be finalized), so each warning is one leaked object
# graph - see quickhea-alz for the memory-growth investigation this feeds.

private module GCDiagnostics
  # Reusable buffer - warn proc must not allocate. Class var so the
  # proc literal can capture it; single-threaded ST scheduler means no
  # concurrent warn-proc invocations.
  BUFFER_SIZE = 160
  @@buffer = uninitialized UInt8[BUFFER_SIZE]

  HEX = "0123456789abcdef"

  def self.install : Nil
    LibGC.set_warn_proc ->(msg : LibC::Char*, v : LibGC::Word) do
      begin
        # 1) Raw message via the same non-allocating path the stock filter uses.
        Crystal::System.print_error msg, v

        # 2) Explicit pointer line (the FreeBSD build's message omits it).
        i = 0
        slice = @@buffer.to_slice
        prefix = "  [gc-diag] finalizable=0x"
        prefix.each_byte do |b|
          slice[i] = b
          i += 1
        end
        value = v
        16.times do |shift|
          digit = ((value >> ((15 - shift) * 4)) & 0xF).to_u8
          next if shift < 15 && value < (1_u64 << ((15 - shift) * 4)) && digit == 0
          slice[i] = HEX.to_unsafe[digit]
          i += 1
        end
        slice[i] = 0x5A_u8 # 'Z'
        i += 1
        slice[i] = 0xA_u8 # '\n'
        i += 1
        Crystal::System.print_error slice[0, i]
      rescue
        # Never let diagnostics take the process down - GC context is fragile.
        # Static message only: interpolation would allocate inside the GC callback.
        begin
          Crystal::System.print_error "  [gc-diag] warn-proc failed\n"
        rescue
        end
      end
    end
  end
end

GCDiagnostics.install
