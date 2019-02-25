Gem::Specification.new do |s|
  s.name     = "jit"
  s.version  = "1.0.0"
  s.summary  = "The information manager from London"
  s.author   = "James Coglan"
  s.email    = "jcoglan@gmail.com"
  s.homepage = "https://shop.jcoglan.com/building-git/"
  s.license  = "GPL-3.0"

  s.files = ["LICENSE.txt"] + Dir.glob("{bin,lib}/**/*")

  s.require_paths = ["lib"]
  s.executables   = ["jit"]
end
