{ pkgs }:
  pkgs.fetchFromGitHub {
    owner = "elixir-lang";
    repo = "elixir";
    rev = "3837f8cfcd558c24ccac5c693fc97f78849a33f6";
    sha256 = "106wvmk52wzkbarlc99dzqw03xqia8gnwx90sdsgm8kkgxhgaffj";
  }
