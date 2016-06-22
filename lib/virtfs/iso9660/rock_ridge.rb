module VirtFS::ISO9660
  # SUSP extensions are present if the first two characters of the SUA of
  # the first directory entry are "SP". After SUSP is identified, if the
  # first two characters of any directory entry's SUA are "RR" a Rock Ridge
  # extension is active for that entry. The particular extension is
  # identified by the two characters after the next two bytes following "RR".

  # NOTE: This implementation is sufficient for Rock Ridge extensions. It will
  # not identify or process any other System Use Sharing Protocol extensions.
  # In particular, SUSP CE (continuation area) records are not processed.

  class PosixAttributes
    attr_reader :flags

    def initialize(data, suffix)
      @flags  = 0
      @suffix = suffix
      @px     = RR_PX.decode(data)
    end

    def mode
      @px["mode#{@suffix}"]
    end

    def nlinks
      @px["links#{@suffix}"]
    end

    def user
      @px["user#{@suffix}"]
    end

    def group
      @px["group#{@suffix}"]
    end

    def file?
      mode & RR_EXT_SL_FM_FILE != 0
    end

    def dir?
      mode & RR_EXT_SL_FM_DIR != 0
    end

    def symlink?
      mode & RR_EXT_SL_FM_LINK != 0
    end
  end # class PosixAttributes

  class SymbolicLink
    attr_reader   :flags
    attr_accessor :link_data

    def initialize(data, _suffix)
      sl = RR_SL.decode(data)

      # Reader data.
      @flags     = sl['flags']
      @link_data = assemble(sl['components'])
    end

    def assemble(data)
      out = ""
      offset = 0

      loop do
        comp     = RR_SL_COMPONENT.decode(data[offset..-1])
        comp_len = comp['length']

        # Check for referential flags.
        out += "./"  if comp['flags'] & RR_EXT_SLCOMPF_CURRENT != 0
        out += "../" if comp['flags'] & RR_EXT_SLCOMPF_PARENT  != 0
        out += "/"   if comp['flags'] & RR_EXT_SLCOMPF_ROOT    != 0

        # Advance offset
        offset += comp_len + 2 # compensate for first two bytes of component.

        # check for done.
        next if comp_len == 0

        # append content
        out = File.join(out, comp['content'][0, comp_len])

        # break if comp['flags'] & RR_EXT_SLCOMPF_CONTINUE == 0
        # Analysis of real data shows the condition is offset >= data len.
        break if offset >= data.length
      end

      out
    end
  end # class SymbolicLink

  class AlternateName
    attr_reader   :flags
    attr_accessor :name

    def current?
      flags & RR_EXT_NMF_CURRENT != 0
    end

    def parent?
      flags & RR_EXT_NMF_PARENT  != 0
    end

    def reserved?
      flags & RR_EXT_NMF_RESERVED3 != 0
    end

    def initialize(data, _suffix)
      an = RR_NM.decode(data)

      # Reader data.
      @flags = an['flags']
      @name += an['content']

      # Check for referential flags.
      @name  = ""
      @name += "./"  if current?
      @name += "../" if parent?

      raise "RR extension NM: RESERVED3 flag is set." if reserved?
    end
  end # class AlternateName

  class Extension
    attr_reader :length, :ext

    def initialize(data, suffix)
      # Get extension header, length & data.
      @header = RR_EXT_HEADER.decode(data)
      @length = @header['length']
      data = data[RR_EXT_HEADER_SIZE, @length - RR_EXT_HEADER_SIZE]

      # Delegate to extension.
      @ext = ext_delegate(data, suffix)
    end

    def ext_delegate(data, suffix)
      case @header['signature']
      when RR_PX_SIGNATURE then PosixAttributes.new(data, suffix)
      when RR_SL_SIGNATURE then SymbolicLink.new(data, suffix)
      when RR_NM_SIGNATURE then AlternateName.new(data, suffix)
      #when RR_SF_SIGNATURE then
      #when RR_PN_SIGNATURE then
      #when RR_CL_SIGNATURE then
      #when RR_PL_SIGNATURE then
      #when RR_RE_SIGNATURE then
      #when RR_TF_SIGNATURE then
      end
    end

    def flags
      ext.flags
    end

    def continue?
      obj.flags & CONTINUE
    end
  end # class Extension

  class RockRidgeAdapter
    SUSP_SIZE = 7
    CONTINUE  = 1

    attr_reader :header, :extensions


    def header_offset
      # Root directories need to skip SUSP header.
      @header_offset ||= @de.name == "." ? SUSP_SIZE : 0
    end

    def header
      @header ||= RR_HEADER.decode(@de.sua[header_offset..-1])
    end

    def signature
      header['signature']
    end

    def valid_signature?
      signature == RR_SIGNATURE
    end

    def initialize(de, suffix)
      raise "No DirectoryEntry specified." if de.nil?
      raise "The specified DirectoryEntry has no System Use Area." if de.sua.nil?
      @de = de

      # Get the RR header from the DirectoryEntry & verify.
      raise "This is not a Rock Ridge extension record" unless valid_signature?

      extract_extensions
      resolve_continuations
    end

    private

    def extract_extensions
      offset = header_offset + RR_HEADER_SIZE
      @extensions = []
      loop do
        offset_data  = de.sua[offset..-1]
        extension    = Extension.new(offset_data, suffix)
        @extensions << extension

        offset += extension.length
        break if offset >= de.sua.length
      end
    end

    def resolve_continuations
      0.upto(@extensions.size - 1) do |idx|
        obj = @extensions[idx]
        next if obj.nil?

        if obj.continue?
          if obj.ext.is_a?(AlternateName)
            obj.name += @extensions[idx + 1].name
            @extensions[idx + 1] = nil

          elsif obj.ext.is_a?(SymbolicLink)
            obj.link_data += @extensions[idx + 1].link_data
            @extensions[idx + 1] = nil
          end
        end
      end

      @extensions.compact!
    end
  end # class RockRidge
end # module VirtFS::ISO9660
