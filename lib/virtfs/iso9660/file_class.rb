require 'active_support/core_ext/object/try' # until we can use the safe nav operator

module VirtFS::ISO9660
  class FS
    def file_atime(p)
      f = get_file(p)
      raise Errno::ENOENT, "No such file or directory" if f.nil?
      f.date
    end

    def file_blockdev?(p)
    end

    def file_chardev?(p)
    end

    def file_chmod(permission, p)
      raise "writes not supported"
    end

    def file_chown(owner, group, p)
      raise "writes not supported"
    end

    def file_ctime(p)
      f = get_file(p)
      raise Errno::ENOENT, "No such file or directory" if f.nil?
      f.date
    end

    def file_delete(p)
      raise "writes not supported"
    end

    def file_directory?(p)
      f = get_file(p)
      !f.nil? && f.dir?
    end

    def file_executable?(p)
    end

    def file_executable_real?(p)
    end

    def file_exist?(p)
      !get_file(p).nil?
    end

    def file_file?(p)
      f = get_file(p)
      !f.nil? && f.file?
    end

    def file_ftype(p)
    end

    def file_grpowned?(p)
    end

    def file_identical?(p1, p2)
    end

    def file_lchmod(permission, p)
      raise "writes not supported"
    end

    def file_lchown(owner, group, p)
      raise "writes not supported"
    end

    def file_link(p1, p2)
      raise "writes not supported"
    end

    def file_lstat(p)
      file = get_file(p)
      raise Errno::ENOENT, "No such file or directory" if file.nil?
      VirtFS::Stat.new(VirtFS::ISO9660::File.new(file, boot_sector).to_h)
    end

    def file_mtime(p)
      f = get_file(p)
      raise Errno::ENOENT, "No such file or directory" if f.nil?
      f.date
    end

    def file_owned?(p)
    end

    def file_pipe?(p)
    end

    def file_readable?(p)
    end

    def file_readable_real?(p)
    end

    def file_readlink(p)
    end

    def file_rename(p1, p2)
      raise "writes not supported"
    end

    def file_setgid?(p)
    end

    def file_setuid?(p)
    end

    def file_size(p)
      f = get_file(p)
      raise Errno::ENOENT, "No such file or directory" if f.nil?
      f.try(:file_size)
    end

    def file_socket?(p)
    end

    def file_stat(p)
    end

    def file_sticky?(p)
    end

    def file_symlink(oname, p)
      raise "writes not supported"
    end

    def file_symlink?(p)
      get_file(p).try(:symlink?)
    end

    def file_truncate(p, len)
      raise "writes not supported"
    end

    def file_utime(atime, mtime, p)
    end

    def file_world_readable?(p)
    end

    def file_world_writable?(p)
      false
    end

    def file_writable?(p)
      false
    end

    def file_writable_real?(p)
      false
    end

    def file_new(f, parsed_args={}, _open_path=nil, _cwd=nil)
      file = get_file(f)
      raise Errno::ENOENT, "No such file or directory" if file.nil?
      file
    end

    private

    def get_file(p)
      # Preprocess path.
      p = unnormalize_path(p)
      dir, fil = ::File.split(p)

      # Fix for FB#835: if fil == root then fil needs to be "."
      fil = "." if fil == "/" || fil == "\\"

      # Look for file in dir, but don't fail if it doesn't exist.
      begin
        return get_dir(dir).try(:find_entry, fil)
      rescue RuntimeError
      end

      nil
    end
  end # class FS
end # module VirtFS::ISO9660
