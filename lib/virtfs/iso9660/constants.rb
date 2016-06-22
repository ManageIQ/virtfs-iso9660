require 'binary_struct'

module VirtFS::ISO9660
  SUPER_OFFSET    = 32768

  MAGIC_OFFSET    = 1
  MAGIC_SIZE      = 5
  MAGIC           = "CD001"

  DEF_CACHE_SIZE  = 50

  PRIMARY_SECTOR  = 16
  JOLIET_SECTOR   = 17

  SECTOR_SIZE     = 2048

  class BootSector
    # Universal Volume Descriptor ID.
    DESCRIPTOR_ID = "CD001"

    # Volume descriptor types.
    TYPE_BOOT       = 0 # The descriptor is a boot record.
    TYPE_PRIM_DESC  = 1 # The descriptor is a primary volume descriptor.
    TYPE_SUPP_DESC  = 2 # The descriptor is a supplementary volume descriptor.
    TYPE_PART_DESC  = 3 # The descriptor is a volume partition descriptor.
    TYPE_TERMINATOR = 255 # Marks the end of descriptor records.
    # NOTE: the spec says terminator is 4, but it seems to be 255.

    # This serves as both the primary and supplementary descriptor structure.
    VOLUME_DESCRIPTOR = BinaryStruct.new([
      'C',    'desc_type',                # TYPE_ enum.
      'a5',   'id',                       # Always "CD001".
      'C',    'version',                  # Must be 1.
      'C',    'vol_flags',                # Unused on primary.
      'a32',  'system_id',                # An 'extra' label.
      'a32',  'volume_id',                # Usually known as label.
      'a8',   'unused2',
      'L',    'vol_space_sizeLE',         # Size in sectors.
      'L',    'vol_space_sizeBE',
      'a32',  'esc_sequences',            # Unused on primary, Joliet CDs do not always record escape sequences (assume UCS-2L3).
      'S',    'vol_set_sizeLE',
      'S',    'vol_set_sizeBE',
      'S',    'vol_seq_numberLE',
      'S',    'vol_seq_numberBE',
      'S',    'log_block_sizeLE',         # Sector size in bytes (so far, alwyas 2048).
      'S',    'log_block_sizeBE',
      'L',    'path_table_sizeLE',        # This implementation ignores the path tables.
      'L',    'path_table_sizeBE',
      'S',    'type_1_path_tableLE',
      'S',    'type_1_path_tableBE',
      'S',    'opt_type_1_path_tableLE',
      'S',    'opt_type_1_path_tableBE',
      'S',    'type_m_path_tableLE',
      'S',    'type_m_path_tableBE',
      'S',    'opt_type_m_path_tableLE',
      'S',    'opt_type_m_path_tableBE',
      'a34',  'root_dir_record',          # DirectoryEntry representing root dir.
      'a128', 'vol_set_id',
      'a128', 'publisher_id',
      'a128', 'preparer_id',
      'a128', 'application_id',
      'a37',  'copyright_file_id',
      'a37',  'abstract_file_id',
      'a37',  'biblographic_file_id',
      'a17',  'creation_date',            # Dates are in ISO long date format.
      'a17',  'modification_date',
      'a17',  'experation_date',
      'a17',  'effective_date',
      'C',    'file_structure_version',   # Must be 1.
      'C',    'unused4',
      'a512', 'application_data',
      'a653', 'unused5'
    ])

    SIZEOF_VOLUME_DESCRIPTOR = VOLUME_DESCRIPTOR.size
  end # class BootSector

  class Directory
    # Find entry flags.
    FE_DIR = 0
    FE_FILE = 1
    FE_EITHER = 2

    # System Use Sharing Protocol header (for Rock Ridge in this implementation).
    SUSP = BinaryStruct.new([
      'a2', 'signature',
      'C',  'len',
      'C',  'version',
      'n',  'check',
      'C',  'skip_bytes'
    ])
    SUSP_SIGNATURE  = "SP"
    SUSP_SIZE       = 7
    SUSP_VERSION    = 1
    SUSP_CHECK_WORD = 0xbeef
  end # class Directory

  # FlagBits: FB_
  FB_HIDDEN     = 0x01  # 0 if not hidden.
  FB_DIRECTORY  = 0x02  # 0 if file.
  FB_ASSOCIATED = 0x04  # 0 if not 'associated' (?)
  FB_RFS        = 0x08  # RecordFormatSpecified: 0 if not.
  FB_PS         = 0x10  # PermissionsSpecified: 0 if not.
  FB_UNUSED1    = 0x20  # No info.
  FB_UNUSED2    = 0x40  # No info.
  FB_NOT_LAST   = 0x80  # 0 if last entry.

  # Extensions.
  EXT_NONE      = 0
  EXT_JOLIET    = 1
  EXT_ROCKRIDGE = 2

  class DirectoryEntry
    DIR_ENT = BinaryStruct.new([
      'C',  'length',           # Bytes, must be even.
      'C',  'ext_attr_length',  # Sectors.
      'L',  'extentLE',         # First sector of data.
      'L',  'extentBE',
      'L',  'sizeLE',           # Size of data in bytes.
      'L',  'sizeBE',
      'a7', 'date',             # ISODATE
      'C',  'flags',            # Flags, see FB_ above.
      'C',  'file_unit_size',   # For interleaved files: not supported.
      'C',  'interleave',       # Not supported.
      'S',  'vol_seq_numLE',    # Not used.
      'S',  'vol_seq_numBE',
      'C',  'name_len',         # Bytes.
    ])
    # Here follows a name. Character set is limited ASCII.
    # Here follows an optional padding byte (if name_len is even).
    # Here follows unspecified extra data, size is included in member length.
    SIZEOF_DIR_ENT = DIR_ENT.size
  end # class DirectoryEntry

  RR_SIGNATURE = "RR"
  RR_HEADER = BinaryStruct.new([
    'a2', 'signature',  # RR if Rock Ridge.
    'C',  'unused1',    # ? always seems to be 5.
    'C',  'unused2',    # ? always seems to be 1 (version?).
    'C',  'unused3'     # ? 0x81
  ])
  RR_HEADER_SIZE = 5

  # These types are not used, but we want to know if they pop up.
  RR_PN_SIGNATURE = "PN"
  RR_CL_SIGNATURE = "CL"
  RR_PL_SIGNATURE = "PL"
  RR_RE_SIGNATURE = "RE"
  RR_TF_SIGNATURE = "TF"

  # POSIX file attributes. See POSIX 5.6.1.
  RR_PX_SIGNATURE = "PX"
  RR_PX = BinaryStruct.new([
    'L',  'modeLE',   # file mode (used to identify a link).
    'L',  'modeBE',
    'L',  'linksLE',  # Num links (st_nlink).
    'L',  'linksBE',
    'L',  'userLE',   # User ID.
    'L',  'userBE',
    'L',  'groupLE',  # Group ID.
    'L',  'groupBE'
    # 'L', 'serialLE', # File serial number.
    # 'L', 'serialBE'
  ])
  # NOTE: IEEE P1282 specifies that file serial number is included, but
  # real data shows this number is absent. Likewise, the spec says the
  # struct length is 44 bytes, where real data shows a length of 36 bytes.
  # It's also worth noting that the real data shows a structure version
  # of 1, so there is definitely disagreement betweeen theory (IEEE P1282)
  # and reality (the Open Solaris developer edition distro iso).

  # File mode bits.
  RR_EXT_SL_FM_SOCK = 0xc000
  RR_EXT_SL_FM_LINK = 0xa000
  RR_EXT_SL_FM_FILE = 0x8000
  RR_EXT_SL_FM_BLOK = 0x6000
  RR_EXT_SL_FM_CHAR = 0x2000
  RR_EXT_SL_FM_DIR  = 0x4000
  RR_EXT_SL_FM_FIFO = 0x1000

  # Symbolic link.
  RR_SL_SIGNATURE = "SL"
  RR_SL = BinaryStruct.new([
    'C',  'flags',  # See RR_EXT_SLF_ below.
    'a*', 'components'
  ])

  # Symbolic link flags.
  RR_EXT_SLF_CONTINUE = 0x01  # Link continues in the next SL entry.

  # A symbolic link component record.
  RR_SL_COMPONENT = BinaryStruct.new([
    'C',  'flags',  # See RR_EXT_SLCOMPF_ below.
    'C',  'length', # Length of content in bytes.
    'a*', 'content'
  ])

  RR_EXT_SLCOMPF_CONTINUE   = 0x01  # Component continues in the next component record.
  RR_EXT_SLCOMPF_CURRENT    = 0x02  # Component refers to the current directory.
  RR_EXT_SLCOMPF_PARENT     = 0x04  # Component refers to the parent directory.
  RR_EXT_SLCOMPF_ROOT       = 0x08  # Component refers to the root directory.
  RR_EXT_SLCOMPF_RESERVED1  = 0x10  # See below.
  RR_EXT_CLCOMPF_RESERVED2  = 0x20  # See below.
  # RESERVED1: Historically, this component has referred to the directory on
  # which the current CD-ROM is mounted.
  # Reserved2: Historically, this component has contained the network node
  # name of the current system as defined in the uname structure of POSIX 4.4.1.2

  # Alternate name.
  RR_NM_SIGNATURE = "NM"
  RR_NM = BinaryStruct.new([
    'C',  'flags',  # See RR_EXT_NMF_ below.
    'a*', 'content'
  ])

  # NOTE: These flag bits are mutually exclusive.
  RR_EXT_NMF_CONTINUE   = 0x01  # Name continues in the next NM entry.
  RR_EXT_NMF_CURRENT    = 0x02  # Name refers to the current directory.
  RR_EXT_NMF_PARENT     = 0x04  # Name refers to the parent directory.
  RR_EXT_NMF_RESERVED1  = 0x08  # Reserved - 0.
  RR_EXT_NMF_RESERVED2  = 0x10  # Reserved - 0.
  RR_EXT_NMF_RESERVED3  = 0x20  # Implementation specific.
  # NOTE: IEEE-P1282 lists the following note about RESERVED3:
  # Historically, this component has contained the network node name of
  # the current system as defined in the uname structure of POSIX 4.4.1.2

  # Common to all RR extensions.
  RR_EXT_HEADER = BinaryStruct.new([
    'a2', 'signature',  # Extension type.
    'C',  'length',     # length in bytes.
    'C',  'version'     # Entry version, always 1.
  ])
  RR_EXT_HEADER_SIZE = 4
end # module VirtFS::ISO9660
