require 'spec_helper'

describe "ISO9660::Dir class methods" do
  before(:all) do
    reset_context

    @full_path = File.expand_path(__FILE__)
    @rel_path  = File.basename(@full_path)
    @spec_dir  = File.dirname(@full_path)
    @root      = File::SEPARATOR

    @iso = build(:iso)
    VirtFS.mount(@iso.fs, @root)
  end

  after(:all) do
    VirtFS.umount(@root)
  end

  describe ".[]" do
    it "should return empty array when in a nonexistent directory" do
      VirtFS.cwd = "/not_a_dir" # bypass existence checks.
      expect(VirtFS::VDir["*"]).to match_array([])
    end

    it "should enumerate the same file names as the standard Dir.glob - simple glob" do
      VirtFS.dir_chdir(@root)
      expect(VirtFS::VDir["*"]).to match_array(@iso.root_dir)
    end

    it "should enumerate the same file names as the standard Dir.glob - relative glob" do
      VirtFS.dir_chdir(@root)
      expect(VirtFS::VDir["*/*"]).to match_array(@iso.glob_dir)
    end
  end

  describe ".chdir" do
    it "should raise Errno::ENOENT when directory doesn't exist" do
      expect do
        VirtFS::VDir.chdir("nonexistent_directory")
      end.to raise_error(
        Errno::ENOENT, "No such file or directory - nonexistent_directory"
      )
    end

    it "should return 0 when no block given" do
      expect(VirtFS::VDir.chdir(@root)).to eq(0)
    end

    it "should return last object of block, when block given" do
      expect(VirtFS::VDir.chdir(@root) { |_path| true }).to be true
    end

    it "should yield the new current directory to the block" do
      expect(VirtFS::VDir.chdir(@root) { |path| path == @root }).to be true
    end
  end

  describe ".delete .rmdir .unlink" do
    it "should raise Runtime Error writes not supported" do
      expect do
        VirtFS::VDir.delete("/not_a_dir/foo.d")
      end.to raise_error(
        RuntimeError, /writes not supported/
      )

      expect do
        VirtFS::VDir.mkdir("/not_a_dir")
      end.to raise_error(
        RuntimeError, /writes not supported/
      )

      expect do
        VirtFS::VDir.mkdir("/not_a_dir")
      end.to raise_error(
        RuntimeError, /writes not supported/
      )

    end
  end

  describe ".entries" do
    it "should raise RuntimeError when given a nonexistent directory" do
      expect do
        VirtFS::VDir.entries("nonexistent_directory")
      end.to raise_error(
        RuntimeError, /Can't find directory: '\/nonexistent_directory'/
      )
    end

    it "should, given full path, return the same file names as the real Dir.entries" do
      expect(VirtFS::VDir.entries(@root)).to match_array(@iso.root_dir + [".", ".."])
    end

    it "should, given relative path, return the same file names as the real Dir.entries" do
      expect(VirtFS::VDir.entries(".")).to match_array(@iso.root_dir + [".", ".."])
    end
  end

  describe ".exist? .exists?" do
    it "should, given full path, return true for this directory" do
      expect(VirtFS::VDir.exist?(@root)).to be true
    end

    it "should, given relative path, return true for this directory" do
      expect(VirtFS::VDir.exist?(".")).to be true
    end
  end

  describe ".foreach" do
    it "should raise Errno::ENOENT when given a nonexistent directory" do
      expect do
        VirtFS::VDir.foreach("nonexistent_directory").to_a
      end.to raise_error(
        RuntimeError, /Can't find directory: '\/nonexistent_directory'/
      )
    end

    it "should return an enum when no block is given" do
      expect(VirtFS::VDir.foreach(@root)).to be_kind_of(Enumerator)
    end

    it "should return nil when block is given" do
      expect(VirtFS::VDir.foreach(@root) { |f| f }).to be_nil
    end

    it "should, given full path, return the same file names as the real Dir.foreach" do
      expect(VirtFS::VDir.foreach(@root).to_a).to match_array(@iso.root_dir + [".", ".."])
    end

    it "should, given relative path, return the same file names as the real Dir.foreach" do
      expect(VirtFS::VDir.foreach(".").to_a).to match_array(@iso.root_dir + [".", ".."])
    end
  end

  describe ".glob" do
    it "should return empty array when in a nonexistent directory" do
      VirtFS.cwd = "/not_a_dir" # bypass existence checks.
      expect(VirtFS::VDir.glob("*")).to match_array([])
    end

    it "should enumerate the same file names as the standard Dir.glob - simple glob" do
      VirtFS.dir_chdir(@root)
      expect(VirtFS::VDir.glob("*")).to match_array(@iso.root_dir)
    end

    it "should enumerate the same file names as the standard Dir.glob - relative glob" do
      VirtFS.dir_chdir(@root)
      expect(VirtFS::VDir.glob("*/*")).to match_array(@iso.glob_dir)
    end
  end

  describe ".mkdir" do
    it "should raise Runtime Error writes not supported" do
      expect do
        VirtFS::VDir.mkdir("/not_a_dir/foo.d")
      end.to raise_error(
        RuntimeError, /writes not supported/
      )
    end
  end

  describe ".new" do
    it "should raise Errno::ENOENT when directory doesn't exist" do
      expect do
        VirtFS::VDir.new("/not_a_dir")
      end.to raise_error(
        RuntimeError, /Can't find directory: '\/not_a_dir'/
      )
    end

    it "should return a directory object - given full path" do
      expect(VirtFS::VDir.new('/')).to be_kind_of(VirtFS::VDir)
    end
  end

  describe ".open" do
    it "should raise Errno::ENOENT when directory doesn't exist" do
      expect do
        VirtFS::VDir.new("/not_a_dir")
      end.to raise_error(
        RuntimeError, /Can't find directory: '\/not_a_dir'/
      )
    end

    it "should return a directory object - when no block given" do
      expect(VirtFS::VDir.open(@root)).to be_kind_of(VirtFS::VDir)
    end

    it "should yield a directory object to the block - when block given" do
      VirtFS::VDir.open(@root) { |dir_obj| expect(dir_obj).to be_kind_of(VirtFS::VDir) }
    end

    it "should return the value of the block - when block given" do
      expect(VirtFS::VDir.open(@root) { true }).to be true
    end
  end
end
