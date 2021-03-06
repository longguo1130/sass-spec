# coding: utf-8
# frozen_string_literal: true

require_relative 'spec_helper'
require 'sass_spec'

RSpec::Matchers.define_negated_matcher :not_include, :include

# A regexp that matches an error message that indicates that a file/directory
# doesn't exist.
DOESNT_EXIST = /No such file or directory|doesn't exist|There is no directory/

describe SassSpec::Directory do
  include_context :uses_fs
  after(:each) { SassSpec::Directory._hrx_cache.clear }

  def directory(folder=nil)
    SassSpec::Directory.new(dir(folder))
  end

  it 'throws an error if the path is the working directory' do
    expect { SassSpec::Directory.new('.') }.to raise_error(". must be beneath the working directory")
  end

  it 'throws an error if the path is outside the working directory' do
    FileUtils.mkdir_p '/foo/bar/baz'
    Dir.chdir '/foo/bar/baz'
    expect { SassSpec::Directory.new('/foo') }.to raise_error("/foo must be beneath the working directory")
  end

  context 'in a real directory' do
    before(:each) { FileUtils.mkdir_p 'spec' }

    it "throws an error if the path doesn't exist" do
      expect { directory('foo') }.to raise_error DOESNT_EXIST
    end

    describe '#path' do
      it 'returns the path relative to the working directory' do
        expect(directory.path).to be == Pathname.new(dir)
      end

      it 'returns a relative path even if passed an absolute path' do
        expect(SassSpec::Directory.new(File.expand_path(dir)).path).to be == Pathname.new(dir)
      end

      it 'uses forward slashes even on Windows' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        expect(directory('foo/bar/baz').path.to_s).to include('/').and not_include("\\")
      end
    end

    describe '#hrx?' do
      it 'returns false' do
        expect(directory).not_to be_hrx
      end
    end

    describe '#parent' do
      it 'returns nil if the parent is the cwd' do
        expect(directory.parent).to be nil
      end

      it 'returns a new directory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        expect(directory('foo/bar/baz').parent.to_s).to be == 'spec/foo/bar'
      end
    end

    describe '#glob' do
      it 'returns matching physical files in the directory' do
        File.write(dir('foo.txt'), '')
        File.write(dir('bar.txt'), '')
        File.write(dir('baz'), '')
        expect(directory.glob('*.txt')).to contain_exactly('foo.txt', 'bar.txt')
      end

      it 'returns matching physical files recursively beneath the directory' do
        FileUtils.mkdir_p(dir('foo/bar/baz'))
        File.write(dir('foo/bar/baz/zip'), '')
        File.write(dir('foo/bar/zap.txt'), '')
        File.write(dir('foo/zop'), '')
        File.write(dir('qux.txt'), '')
        expect(directory.glob('**/*.txt')).to contain_exactly('foo/bar/zap.txt', 'qux.txt')
      end

      it 'returns files recursively within an HRX archive' do
        FileUtils.mkdir_p(dir('foo'))
        File.write(dir('foo/bar.hrx'), <<END)
<===> baz/zip.txt
zip
<===> qux/zap
zap
<===> zop.txt
zop
END
        expect(directory.glob('**/*.txt'))
          .to contain_exactly('foo/bar/baz/zip.txt', 'foo/bar/zop.txt')
      end

      it 'returns all files recursively within the directory or an HRX archive' do
        FileUtils.mkdir_p(dir('foo'))
        File.write(dir('foo/bar.hrx'), <<END)
<===> baz/zip
zip
<===> zap
zap
END
        File.write(dir('foo/qux'), '')
        File.write(dir('bang'), '')
        expect(directory.glob('**/*'))
          .to contain_exactly('foo/bar/baz/zip', 'foo/bar/zap', 'foo/qux', 'bang')
      end

      it "doesn't return an HRX archive itself" do
        File.write(dir('foo.hrx'), '')
        expect(directory.glob('*')).to be_empty
      end

      it "ignores HRX archives when run non-recursively" do
        File.write(dir('foo.hrx'), '<===> bar.txt\nbar')
        expect(directory.glob('*.txt')).to be_empty
      end
    end

    describe '#file?' do
      it 'returns true if the given file exists' do
        File.write(dir('qux.txt'), 'hello!')
        expect(directory.file?('qux.txt')).to be true
      end

      it 'returns true if the given file exists in a subdirectory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        File.write(dir('foo/bar/baz/qux.txt'), 'hello!')
        expect(directory.file?('foo/bar/baz/qux.txt')).to be true
      end

      it 'returns true if the given file exists in an HRX archive' do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), <<END)
<===> baz/qux.txt
hello!
END
        expect(directory.file?('foo/bar/baz/qux.txt')).to be true
      end

      it 'treats the path as relative to the directory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        File.write(dir('foo/bar/baz/qux.txt'), 'hello!')
        expect(directory('foo/bar/baz').file?('qux.txt')).to be true
      end

      it "returns false if the given file doesn't exist" do
        expect(directory.file?('qux.txt')).to be false
      end

      it "returns false if the given file doesn't exist in a subdirectory" do
        expect(directory.file?('foo/bar/baz/qux.txt')).to be false
      end

      it "returns false if the given file doesn't exist in an HRX archive" do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), '')
        expect(directory.file?('foo/bar/baz/qux.txt')).to be false
      end

      it "returns false if a directory with the given name exists" do
        FileUtils.mkdir dir('subdir')
        expect(directory.file?('subdir')).to be false
      end
    end

    describe '#read' do
      it 'returns the contents of the given file' do
        File.write(dir('qux.txt'), 'hello!')
        expect(directory.read('qux.txt')).to be == 'hello!'
      end

      it 'returns the contents of a file in a subdirectory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        File.write(dir('foo/bar/baz/qux.txt'), 'hello!')
        expect(directory.read('foo/bar/baz/qux.txt')).to be == 'hello!'
      end

      it 'returns the contents of a file in an HRX archive' do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), "<===> baz/qux.txt\nhello!")
        expect(directory.read('foo/bar/baz/qux.txt')).to be == 'hello!'
      end

      it 'treats the path as relative to the directory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        File.write(dir('foo/bar/baz/qux.txt'), 'hello!')
        expect(directory('foo/bar/baz').read('qux.txt')).to be == 'hello!'
      end

      context 'with a real filesystem' do
        # FakeFS doesn't seem to respect `File.read()`'s encoding.
        include_context :uses_real_fs

        it 'reads the file as binary' do
          FileUtils.mkdir_p 'spec'
          File.write('spec/qux.txt', '👭')
          expect(SassSpec::Directory.new('spec').read('qux.txt'))
            .to be == '👭'.dup.force_encoding('ASCII-8BIT')
        end
      end

      it "throws an error if the file doesn't exist" do
        expect { directory.read('qux.txt') }.to raise_error DOESNT_EXIST
      end

      it "throws an error if the given file doesn't exist in a subdirectory" do
        expect { expect(directory.read('foo/bar/baz/qux.txt')) }.to raise_error DOESNT_EXIST
      end

      it "throws an error if the given file doesn't exist in an HRX archive" do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), '')
        expect { directory.read('foo/bar/baz/qux.txt') }.to raise_error DOESNT_EXIST
      end
    end

    describe '#write' do
      it 'writes the contents of the given file' do
        directory.write('qux.txt', 'hello!')
        expect(File.read(dir('qux.txt'))).to be == 'hello!'
      end

      it 'writes the file in a subdirectory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        directory.write('foo/bar/baz/qux.txt', 'hello!')
        expect(File.read(dir('foo/bar/baz/qux.txt'))).to be == 'hello!'
      end

      it 'writes the file in an HRX archive' do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), '')
        directory.write('foo/bar/baz.txt', 'hello!')
        expect(File.read(dir('foo/bar.hrx'))).to be == "<===> baz.txt\nhello!"
      end

      it 'writes the contents of a file in an HRX archive' do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), "<===> baz/qux.txt\nhello!")
        expect(directory.read('foo/bar/baz/qux.txt')).to be == 'hello!'
      end

      it 'treats the path as relative to the directory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        directory('foo/bar/baz').write('qux.txt', 'hello!')
        expect(File.read(dir('foo/bar/baz/qux.txt'))).to be == 'hello!'
      end

      it "throws an error if the given subdirectory doesn't exist" do
        expect { expect(directory.write('foo/bar/baz/qux.txt', 'hello!')) }
          .to raise_error DOESNT_EXIST
      end

      it "throws an error if the given subdirectory doesn't exist within an HRX archive" do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), '')
        expect { expect(directory.write('foo/bar/baz/qux.txt', 'hello!')) }
          .to raise_error DOESNT_EXIST
      end
    end

    describe '#delete' do
      it 'deletes the given file' do
        File.write(dir('qux.txt'), '')
        directory.delete('qux.txt')
        expect(File.exists?(dir('qux.txt'))).to be false
      end

      it 'deletes the file in a subdirectory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        File.write(dir('foo/bar/baz/qux.txt'), 'hello!')
        directory.delete('foo/bar/baz/qux.txt')
        expect(File.exists?(dir('foo/bar/baz/qux.txt'))).to be false
      end

      it 'deletes the file in an HRX archive' do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), <<END)
<===> baz/bang.txt
bang!
<===> baz/qux.txt
qux?
<===> zip/zap.txt
zop~
END
        directory.delete('foo/bar/baz/qux.txt')
        expect(File.read(dir('foo/bar.hrx'))).to be == <<END
<===> baz/bang.txt
bang!
<===> zip/zap.txt
zop~
END
      end

      it 'treats the path as relative to the directory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        File.write(dir('foo/bar/baz/qux.txt'), '')
        directory('foo/bar/baz').delete('qux.txt')
        expect(File.exists?(dir('foo/bar/baz/qux.txt'))).to be false
      end

      it "throws an error if the file doesn't exist" do
        expect { directory.delete('qux.txt') }.to raise_error DOESNT_EXIST
      end

      it "throws an error if the given subdirectory doesn't exist" do
        expect { expect(directory.delete('foo/bar/baz/qux.txt')) }.to raise_error DOESNT_EXIST
      end

      it "throws an error if the given subdirectory doesn't exist within an HRX archive" do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), '')
        expect { expect(directory.delete('foo/bar/baz/qux.txt')) }
          .to raise_error DOESNT_EXIST
      end

      context 'with if_exists' do
        it 'deletes the given file' do
          File.write(dir('qux.txt'), '')
          directory.delete('qux.txt', if_exists: true)
          expect(File.exists?(dir('qux.txt'))).to be false
        end

        it "does nothing if the file doesn't exist" do
          expect { directory.delete('qux.txt', if_exists: true) }.not_to raise_error
        end
      end
    end

    describe '#rename' do
      it 'moves the given file' do
        File.write(dir('qux.txt'), 'hello!')
        directory.rename('qux.txt', 'zip.txt')
        expect(File.read(dir('zip.txt'))).to be == 'hello!'
        expect(File.exists?(dir('qux.txt'))).to be false
      end

      it 'moves the file within a subdirectory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        File.write(dir('foo/bar/baz/qux.txt'), 'hello!')
        directory.rename('foo/bar/baz/qux.txt', 'foo/bar/baz/zip.txt')
        expect(File.read(dir('foo/bar/baz/zip.txt'))).to be == 'hello!'
        expect(File.exists?(dir('foo/bar/baz/qux.txt'))).to be false
      end

      it 'moves the file between subdirectories' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        FileUtils.mkdir_p dir('do/re/me')
        File.write(dir('foo/bar/baz/qux.txt'), 'hello!')
        directory.rename('foo/bar/baz/qux.txt', 'do/re/me/fa.txt')
        expect(File.read(dir('do/re/me/fa.txt'))).to be == 'hello!'
        expect(File.exists?(dir('foo/bar/baz/qux.txt'))).to be false
      end

      it 'moves the file within an HRX archive' do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), "<===> baz/qux.txt\nhello!")
        directory.rename('foo/bar/baz/qux.txt', 'foo/bar/baz/zap.txt')
        expect(File.read(dir('foo/bar.hrx'))).to be == "<===> baz/zap.txt\nhello!"
      end

      it 'moves the file out of an HRX archive' do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), "<===> baz/qux.txt\nhello!")
        directory.rename('foo/bar/baz/qux.txt', 'qux.txt')
        expect(File.exists?(dir('foo/bar.hrx'))).to be false
        expect(File.read(dir('qux.txt'))).to be === 'hello!'
      end

      it 'moves the file into an HRX archive' do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), '')
        File.write(dir('qux.txt'), 'hello!')
        directory.rename('qux.txt', 'foo/bar/baz.txt')
        expect(File.exists?(dir('qux.txt'))).to be false
        expect(File.read(dir('foo/bar.hrx'))).to be === "<===> baz.txt\nhello!"
      end

      it 'moves the file between HRX archives' do
        FileUtils.mkdir_p dir('foo')
        File.write(dir('foo/bar.hrx'), "<===> baz/qux.txt\nhello!")
        File.write(dir('foo/zip.hrx'), '')
        directory.rename('foo/bar/baz/qux.txt', 'foo/zip/zap.txt')
        expect(File.exists?(dir('foo/bar.hrx'))).to be false
        expect(File.read(dir('foo/zip.hrx'))).to be === "<===> zap.txt\nhello!"
      end

      it 'treats the path as relative to the directory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        File.write(dir('foo/bar/baz/qux.txt'), 'hello!')
        directory('foo/bar/baz').rename('qux.txt', 'zip.txt')
        expect(File.read(dir('foo/bar/baz/zip.txt'))).to be == 'hello!'
        expect(File.exists?(dir('foo/bar/baz/qux.txt'))).to be false
      end

      it "throws an error if the file doesn't exist" do
        expect { directory.rename('qux.txt', 'zap.txt') }.to raise_error DOESNT_EXIST
      end

      it "throws an error if the target directory doesn't exist" do
        File.write(dir('qux.txt'), 'hello!')
        expect { directory.rename('qux.txt', 'foo/zap.txt') }.to raise_error DOESNT_EXIST
      end
    end

    describe '#delete_dir!' do
      it 'deletes the directory' do
        directory.delete_dir!
        expect(Dir.exists?(dir)).to be false
      end

      it 'deletes the directory even if it contains files' do
        File.write(dir('foo.txt'), '')
        File.write(dir('bar.txt'), '')
        File.write(dir('baz.txt'), '')
        directory.delete_dir!
        expect(Dir.exists?(dir)).to be false
      end

      it 'deletes the directory even if it contains subdirectories' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        File.write(dir('foo/bar/baz/qux.txt'), '')
        directory.delete_dir!
      end

      it 'treats the path as relative to the directory' do
        FileUtils.mkdir_p dir('foo/bar/baz')
        directory('foo/bar/baz').delete_dir!
        expect(Dir.exists?(dir('foo/bar/baz'))).to be false
        expect(Dir.exists?(dir('foo/bar'))).to be true
      end
    end

    describe '#with_real_files' do
      it 'runs the block without any filesystem changes' do
        dir = directory
        dir.write('qux.txt', 'hello!')
        dir.with_real_files do
          expect(File.read(dir('qux.txt'))).to be == 'hello!'
        end
      end

      it 'forwards the return value from the block' do
        expect(directory.with_real_files {:result}).to be :result
      end
    end

    describe '#to_hrx' do
      it 'returns an empty string for an empty directory' do
        expect(directory.to_hrx).to be_empty
      end

      it 'returns files in the directory' do
        dir = directory
        dir.write('foo.txt', 'foo')
        dir.write('bar.txt', 'bar')
        dir.write('baz.txt', 'baz')

        # Slice the string because directory ordering is not guaranteed.
        expect(dir.to_hrx.split("\n").each_slice(2).map {|s| s.join("\n")}).to contain_exactly(
          "<===> spec/foo.txt\nfoo",
          "<===> spec/bar.txt\nbar",
          "<===> spec/baz.txt\nbaz"
        )
      end

      it 'returns files in subdirectories' do
        FileUtils.mkdir_p(dir('foo/bar/baz'))
        File.write(dir('foo/bar/baz/qux.txt'), 'hello!')
        expect(directory.to_hrx).to be == "<===> spec/foo/bar/baz/qux.txt\nhello!"
      end

      it 'returns files in HRX archives' do
        File.write(dir('archive.hrx'), <<END)
<===> foo.txt
foo
<===> subdir/bar.txt
bar
END
        expect(directory.to_hrx).to be == <<END
<===> spec/archive/foo.txt
foo
<===> spec/archive/subdir/bar.txt
bar
END
      end
    end
  end

  context 'in an HRX directory' do
    it "throws an error if the path doesn't exist" do
      File.write('spec.hrx', '')
      expect { directory('foo') }.to raise_error DOESNT_EXIST
    end

    describe '#path' do
      it 'returns the path relative to the working directory' do
        File.write('spec.hrx', '')
        expect(directory.path).to be == Pathname.new(dir)
      end

      it 'returns a relative path even if passed an absolute path' do
        File.write('spec.hrx', '')
        expect(SassSpec::Directory.new(File.expand_path(dir)).path).to be == Pathname.new(dir)
      end

      it 'uses forward slashes even on Windows' do
        File.write('spec.hrx', "<===> foo/bar/baz/bang.txt\nbang")
        expect(directory('foo/bar/baz').path.to_s).to include('/').and not_include("\\")
      end
    end

    describe '#hrx?' do
      it 'returns false' do
        File.write('spec.hrx', '')
        expect(directory).to be_hrx
      end
    end

    describe '#parent' do
      it 'returns nil if the parent is the cwd' do
        File.write('spec.hrx', '')
        expect(directory.parent).to be nil
      end

      it 'returns a new directory' do
        File.write('spec.hrx', "<===> foo/bar/baz/bang.txt\nbang")
        FileUtils.mkdir_p dir('foo/bar/baz')
        expect(directory('foo/bar/baz').parent.to_s).to be == 'spec/foo/bar'
      end
    end

    describe '#glob' do
      it 'returns matching files in the directory' do
        File.write('spec.hrx', <<END)
<===> foo.txt
foo
<===> bar.txt
bar
<===> baz
baz
END
        expect(directory.glob('*.txt')).to contain_exactly('foo.txt', 'bar.txt')
      end

      it "doesn't return directories" do
        File.write('spec.hrx', "<===> foo/\n")
        expect(directory.glob('*')).to be_empty
      end
    end

    describe '#file?' do
      it 'returns true if the given file exists' do
        File.write('spec.hrx', "<===> qux.txt\nhello!")
        expect(directory.file?('qux.txt')).to be true
      end

      it 'returns true if the given file exists in a subdirectory' do
        File.write('spec.hrx', "<===> foo/bar/baz/qux.txt\nhello!")
        expect(directory.file?('foo/bar/baz/qux.txt')).to be true
      end

      it 'treats the path as relative to the directory' do
        File.write('spec.hrx', "<===> foo/bar/baz/qux.txt\nhello!")
        expect(directory('foo/bar/baz').file?('qux.txt')).to be true
      end

      it "returns false if the given file doesn't exist" do
        File.write('spec.hrx', '')
        expect(directory.file?('qux.txt')).to be false
      end

      it "returns false if the given file doesn't exist in a subdirectory" do
        File.write('spec.hrx', '')
        expect(directory.file?('foo/bar/baz/qux.txt')).to be false
      end

      it "returns false if a directory with the given name exists" do
        File.write('spec.hrx', "<===> subdir/\n")
        expect(directory.file?('subdir')).to be false
      end
    end

    describe '#read' do
      it 'returns the contents of the given file' do
        File.write('spec.hrx', "<===> qux.txt\nhello!")
        expect(directory.read('qux.txt')).to be == 'hello!'
      end

      it 'returns the contents of a file in a subdirectory' do
        File.write('spec.hrx', "<===> foo/bar/baz/qux.txt\nhello!")
        expect(directory.read('foo/bar/baz/qux.txt')).to be == 'hello!'
      end

      it 'treats the path as relative to the directory' do
        File.write('spec.hrx', "<===> foo/bar/baz/qux.txt\nhello!")
        expect(directory('foo/bar/baz').read('qux.txt')).to be == 'hello!'
      end

      it "throws an error if the file doesn't exist" do
        File.write('spec.hrx', '')
        expect { directory.read('qux.txt') }.to raise_error(/There is no file/)
      end

      it "throws an error if the given file doesn't exist in a subdirectory" do
        File.write('spec.hrx', '')
        expect { expect(directory.read('foo/bar/baz/qux.txt')) }.to raise_error(/There is no file/)
      end
    end

    describe '#write' do
      it 'writes the contents of the given file' do
        File.write('spec.hrx', '')
        directory.write('qux.txt', 'hello!')
        expect(File.read('spec.hrx')).to be == "<===> qux.txt\nhello!"
      end

      it 'writes the file in a subdirectory' do
        File.write('spec.hrx', '')
        directory.write('foo/bar/baz/qux.txt', 'hello!')
        expect(File.read('spec.hrx')).to be == "<===> foo/bar/baz/qux.txt\nhello!"
      end

      it 'treats the path as relative to the directory' do
        File.write('spec.hrx', "<===> foo/bar/baz/zap.txt\nzap")
        directory('foo/bar/baz').write('qux.txt', "hello!\n")
        expect(File.read('spec.hrx')).to be == <<END
<===> foo/bar/baz/zap.txt
zap
<===> foo/bar/baz/qux.txt
hello!
END
      end
    end

    describe '#delete' do
      it 'deletes the given file' do
        File.write('spec.hrx', <<END)
<===> qux.txt
hello
<===> zap.txt
world
END
        directory.delete('qux.txt')
        expect(File.read('spec.hrx')).to be == "<===> zap.txt\nworld\n"
      end

      it "deletes the HRX file if the given file is the last one" do
        File.write('spec.hrx', "<===> qux.txt\nhello!")
        directory.delete('qux.txt')
        expect(File.exists?('spec.hrx')).to be false
      end

      it 'deletes the file in a subdirectory' do
        File.write('spec.hrx', <<END)
<===> foo/bar/baz/qux.txt
hello
<===> zap.txt
world
END
        directory.delete('foo/bar/baz/qux.txt')
        expect(File.read('spec.hrx')).to be == "<===> zap.txt\nworld\n"
      end

      it 'treats the path as relative to the directory' do
        File.write('spec.hrx', "<===> foo/bar/baz/qux.txt\nhello!")
        directory('foo/bar/baz').delete('qux.txt')
        expect(File.exists?('spec.hrx')).to be false
      end

      it "throws an error if the file doesn't exist" do
        File.write('spec.hrx', '')
        expect { directory.delete('qux.txt') }.to raise_error(/doesn't exist/)
      end

      it "throws an error if the given subdirectory doesn't exist" do
        File.write('spec.hrx', '')
        expect { expect(directory.delete('foo/bar/baz/qux.txt')) }.to raise_error DOESNT_EXIST
      end

      context 'with if_exists' do
        it 'deletes the given file' do
          File.write('spec.hrx', <<END)
<===> qux.txt
hello
<===> zap.txt
world
END
          directory.delete('qux.txt', if_exists: true)
          expect(File.read('spec.hrx')).to be == "<===> zap.txt\nworld\n"
        end

        it "does nothing if the file doesn't exist" do
          File.write('spec.hrx', "<===> zap.txt\nworld")
          expect { directory.delete('qux.txt', if_exists: true) }.not_to raise_error
          expect(File.read('spec.hrx')).to be == "<===> zap.txt\nworld"
        end
      end
    end

    describe '#rename' do
      it 'moves the given file' do
        File.write('spec.hrx', "<===> qux.txt\nhello!")
        directory.rename('qux.txt', 'zip.txt')
        expect(File.read('spec.hrx')).to be == "<===> zip.txt\nhello!"
      end

      it 'preserves an HRX comment' do
        File.write('spec.hrx', <<END)
<===>
comment!
<===> qux.txt
hello!
END
        directory.rename('qux.txt', 'zip.txt')
        expect(File.read('spec.hrx')).to be == <<END
<===>
comment!
<===> zip.txt
hello!
END
      end

      it 'moves the file within a subdirectory' do
        File.write('spec.hrx', "<===> foo/bar/baz/qux.txt\nhello!")
        directory.rename('foo/bar/baz/qux.txt', 'foo/bar/baz/zip.txt')
        expect(File.read('spec.hrx')).to be == "<===> foo/bar/baz/zip.txt\nhello!"
      end

      it 'moves the file between subdirectories' do
        File.write('spec.hrx', <<END)
<===> foo/bar/baz/qux.txt
hello!

<===> do/re/me/zap.txt
zap
END
        directory.rename('foo/bar/baz/qux.txt', 'do/re/me/fa.txt')
        expect(File.read('spec.hrx')).to be == <<END
<===> do/re/me/zap.txt
zap

<===> do/re/me/fa.txt
hello!
END
      end

      it 'treats the path as relative to the directory' do
        File.write('spec.hrx', "<===> foo/bar/baz/qux.txt\nhello!")
        directory('foo/bar/baz').rename('qux.txt', 'zip.txt')
        expect(File.read('spec.hrx')).to be == "<===> foo/bar/baz/zip.txt\nhello!"
      end

      it "throws an error if the file doesn't exist" do
        File.write('spec.hrx', '')
        expect { directory.rename('qux.txt', 'zap.txt') }.to raise_error(/doesn't exist/)
      end

      it "throws an error if the target directory doesn't exist" do
        File.write('spec.hrx', "<===> foo/qux.txt\nhello!")
        expect { directory.rename('qux.txt', 'foo/zap.txt') }.to raise_error DOESNT_EXIST
      end
    end

    describe '#delete_dir!' do
      it 'deletes the entire HRX file' do
        File.write('spec.hrx', '')
        directory.delete_dir!
        expect(File.exists?('spec.hrx')).to be false
      end

      it 'deletes a subdirectory within an HRX file' do
        File.write('spec.hrx', <<END)
<===> foo/bar/baz.txt
baz
<===> foo/bar/bang.txt
bang
<===> foo/qux.txt
qux
END
        directory('foo/bar').delete_dir!
        File.write('spec.hrx', "<===> foo/qux.txt\nqux")
      end

      it "deletes a parent HRX file if it's now empty" do
        File.write('spec.hrx', <<END)
<===> foo/bar/baz.txt
baz
<===> foo/bar/bang.txt
bang
END
        directory('foo/bar').delete_dir!
        expect(File.exists?('spec.hrx')).to be false
      end
    end

    describe '#with_real_files' do
      it 'creates physical files for files in the archive' do
        File.write('spec.hrx', <<END)
<===> foo.txt
foo
<===> bar.txt
bar
<===> baz.txt
baz
END

        directory.with_real_files do
          expect(File.read('spec/foo.txt')).to be == 'foo'
          expect(File.read('spec/bar.txt')).to be == 'bar'
          expect(File.read('spec/baz.txt')).to be == "baz\n"
        end
      end

      it 'deletes physical files after the block' do
        File.write('spec.hrx', "<===> foo.txt\nfoo")
        directory.with_real_files {}
        expect(Dir.exists?('spec')).to be false
      end

      it 'only materializes a subdirectory if necessary' do
        File.write('spec.hrx', <<END)
<===> foo/bar/baz/qux.txt
qux
<===> foo/bar/baz.txt
baz
<===> foo/bar.txt
bar
END

        directory('foo/bar/baz').with_real_files do
          expect(File.read('spec/foo/bar/baz/qux.txt')).to be == 'qux'
          expect(File.exists?('spec/foo/bar/baz.txt')).to be false
          expect(File.exists?('spec/foo/bar.txt')).to be false
        end
      end

      it 'deletes the parent directory after a subdirectory is materialized' do
        File.write('spec.hrx', "<===> foo/bar/baz/qux.txt\nhello!")
        directory('foo/bar/baz').with_real_files {}
        expect(Dir.exists?('spec')).to be false
      end

      it 'only materializes a parent directory if the subdirectory reaches out' do
        File.write('spec.hrx', <<END)
<===> foo/bar/baz/qux.txt
../../bar.txt
<===> foo/bar.txt
bar
<===> foo.txt
foo
END

        directory('foo/bar/baz').with_real_files do
          expect(File.read('spec/foo/bar/baz/qux.txt')).to be == '../../bar.txt'
          expect(File.read('spec/foo/bar.txt')).to be == 'bar'
          expect(File.exists?('spec/foo.txt')).to be false
        end
      end
    end

    describe '#to_hrx' do
      it 'returns an empty string for an empty directory' do
        File.write('spec.hrx', '')
        expect(directory.to_hrx).to be_empty
      end

      it 'returns files in the directory' do
        File.write('spec.hrx', <<END)
<===> foo.txt
foo
<===> bar.txt
bar
<===> baz.txt
baz
END

        expect(directory.to_hrx).to be == <<END
<===> spec/foo.txt
foo
<===> spec/bar.txt
bar
<===> spec/baz.txt
baz
END
      end

      it 'returns files in subdirectories' do
        File.write('spec.hrx', "<===> foo/bar/baz/qux.txt\nhello!")
        expect(directory.to_hrx).to be == "<===> spec/foo/bar/baz/qux.txt\nhello!"
      end
    end
  end
end
