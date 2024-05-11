class Ldc < Formula
  desc "Portable D programming language compiler"
  homepage "https://wiki.dlang.org/LDC"
  url "https://github.com/ldc-developers/ldc/releases/download/v1.38.0/ldc-1.38.0-src.tar.gz"
  sha256 "ca6238efe022e34cd3076741f8a070c6a377196351c61949a48a48c99379f38e"
  license "BSD-3-Clause"
  head "https://github.com/ldc-developers/ldc.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256                               arm64_sonoma:   "c2b5260191314ff8f7d6322ceeeba130eda68c5d430f4a904b329239580f0581"
    sha256                               arm64_ventura:  "aba44f09fcbc206be33065644e7c9856fdd5d7b5ca6026e460db68153eea8851"
    sha256                               arm64_monterey: "62f8986d5cf578391cb982466101c3b8e81dba54de18160207e370d3ad6c8b49"
    sha256                               sonoma:         "bb59d616c45576dd073c239a4ca89e4c618a8b1c6c4d751ca198ef20e0bc8072"
    sha256                               ventura:        "cd88c05ccd585e2b90943e9b6ebf9bcf89c48b5d3e824dbbc8581aaf04a89647"
    sha256                               monterey:       "3d9dfd21243a9f1f7e211a6651ac209d3ca3424d9794bb9a5a657e29fe0d3a46"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "2aab9ffeff6ba4d7a6a40fd9b55812cbcbf29cc21ebece64078cb426a405bafc"
  end

  depends_on "cmake" => :build
  depends_on "libconfig" => :build
  depends_on "pkg-config" => :build
  depends_on "llvm"

  uses_from_macos "libxml2" => :build

  resource "ldc-bootstrap" do
    on_macos do
      on_arm do
        url "https://github.com/ldc-developers/ldc/releases/download/v1.38.0/ldc2-1.38.0-osx-arm64.tar.xz"
        sha256 "bfcad81853462a1308c045f1c82b641c3ac007000c5f7de269172067e60a6dea"
      end
      on_intel do
        url "https://github.com/ldc-developers/ldc/releases/download/v1.38.0/ldc2-1.38.0-osx-x86_64.tar.xz"
        sha256 "d52e1bc5634f045528083d5088b8cfb936b5ab9c041aaaa604902dbf82eef76b"
      end
    end
    on_linux do
      on_arm do
        url "https://github.com/ldc-developers/ldc/releases/download/v1.38.0/ldc2-1.38.0-linux-aarch64.tar.xz"
        sha256 "3d17aae84f7500a0e0ad5a3b6a4c6398415d2a4cd330216a4b15a3b4d3a2edea"
      end
      on_intel do
        url "https://github.com/ldc-developers/ldc/releases/download/v1.38.0/ldc2-1.38.0-linux-x86_64.tar.xz"
        sha256 "e5108a5ae7ca135623f79569182929a2aab117767a6fb85b599338648b7e7737"
      end
    end
  end

  def llvm
    deps.reject { |d| d.build? || d.test? }
        .map(&:to_formula)
        .find { |f| f.name.match?(/^llvm(@\d+)?$/) }
  end

  def install
    ENV.cxx11
    # Fix ldc-bootstrap/bin/ldmd2: error while loading shared libraries: libxml2.so.2
    ENV.prepend_path "LD_LIBRARY_PATH", Formula["libxml2"].opt_lib if OS.linux?
    # Work around LLVM 16+ build failure due to missing -lzstd when linking lldELF
    # Issue ref: https://github.com/ldc-developers/ldc/issues/4478
    inreplace "CMakeLists.txt", " -llldELF ", " -llldELF -lzstd "

    (buildpath/"ldc-bootstrap").install resource("ldc-bootstrap")

    args = %W[
      -DLLVM_ROOT_DIR=#{llvm.opt_prefix}
      -DINCLUDE_INSTALL_DIR=#{include}/dlang/ldc
      -DD_COMPILER=#{buildpath}/ldc-bootstrap/bin/ldmd2
      -DCMAKE_INSTALL_RPATH=#{rpath}
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    # Don't set CC=llvm_clang since that won't be in PATH,
    # nor should it be used for the test.
    ENV.method(DevelopmentTools.default_compiler).call

    (testpath/"test.d").write <<~EOS
      import std.stdio;
      void main() {
        writeln("Hello, world!");
      }
    EOS
    system bin/"ldc2", "test.d"
    assert_match "Hello, world!", shell_output("./test")
    system bin/"ldc2", "-flto=thin", "test.d"
    assert_match "Hello, world!", shell_output("./test")
    system bin/"ldc2", "-flto=full", "test.d"
    assert_match "Hello, world!", shell_output("./test")
    system bin/"ldmd2", "test.d"
    assert_match "Hello, world!", shell_output("./test")
  end
end
